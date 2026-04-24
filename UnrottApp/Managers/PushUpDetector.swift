import Foundation
import AVFoundation
import Vision
import CoreGraphics

// Struktur für die Skelett-Linien
struct SkeletonLine: Identifiable {
    let id = UUID()
    let start: CGPoint
    let end: CGPoint
}

final class PushUpDetector: NSObject, ObservableObject {
    @Published private(set) var pushUpCount = 0
    @Published private(set) var earnedMinutes = 0
    @Published private(set) var permissionDenied = false
    @Published private(set) var isRunning = false
    @Published private(set) var smoothedElbowAngle: Double = 180
    
    // NEU: Diese Variable wird von der View genutzt, um die grünen Linien zu zeichnen
    @Published private(set) var skeletonLines: [SkeletonLine] = []

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.unrott.camera-session")
    private let visionQueue = DispatchQueue(label: "com.unrott.vision-queue")
    private let videoOutput = AVCaptureVideoDataOutput()

    private var isConfigured = false
    private enum RepPhase { case up, down }
    private var repPhase: RepPhase = .up
    private var downStartDate: Date?
    private var lastRepDate = Date.distantPast
    private var angleWindow: [Double] = []

    private let maxWindowSize = 6
    private let downAngleThreshold = 105.0 // Leicht angepasst für bessere Erkennung
    private let upAngleThreshold = 150.0
    private let minDownHold: TimeInterval = 0.15
    private let minRepInterval: TimeInterval = 0.6
    private let confidenceThreshold: VNConfidence = 0.3

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permissionDenied = false
            prepareAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionDenied = !granted
                    if granted { self?.prepareAndStartSession() }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            if self?.session.isRunning == true { self?.session.stopRunning() }
            DispatchQueue.main.async { 
                self?.isRunning = false
                self?.skeletonLines = [] // Linien löschen beim Stop
            }
        }
    }

    func resetCounters() {
        DispatchQueue.main.async {
            self.pushUpCount = 0
            self.earnedMinutes = 0
            self.smoothedElbowAngle = 180
            self.skeletonLines = []
        }
        visionQueue.async { [weak self] in
            self?.repPhase = .up
            self?.downStartDate = nil
            self?.lastRepDate = Date.distantPast
            self?.angleWindow.removeAll()
        }
    }

    private func prepareAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.isConfigured { self.configureSession() }
            guard self.isConfigured else { return }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        guard let camera = camera, let input = try? AVCaptureDeviceInput(device: camera) else { return }
        if session.canAddInput(input) { session.addInput(input) }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        videoOutput.connection(with: .video)?.videoOrientation = .portrait
        isConfigured = true
    }

    private func analyze(sampleBuffer: CMSampleBuffer) {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { 
                DispatchQueue.main.async { self.skeletonLines = [] }
                return 
            }
            
            // Skelett-Linien berechnen
            updateSkeleton(from: observation)

            if let elbowAngle = computeElbowAngle(from: observation) {
                processSmoothedAngle(elbowAngle)
            }
        } catch { return }
    }

    // NEU: Berechnet die grünen Linien für die Arme
    private func updateSkeleton(from observation: VNHumanBodyPoseObservation) {
        guard let points = try? observation.recognizedPoints(.all) else { return }
        var newLines: [SkeletonLine] = []
        
        func addLine(from j1: VNHumanBodyPoseObservation.JointName, to j2: VNHumanBodyPoseObservation.JointName) {
            if let p1 = point(j1, from: points), let p2 = point(j2, from: points) {
                newLines.append(SkeletonLine(start: p1, end: p2))
            }
        }

        // Arme und Schultern verbinden
        addLine(from: .leftShoulder, to: .leftElbow)
        addLine(from: .leftElbow, to: .leftWrist)
        addLine(from: .rightShoulder, to: .rightElbow)
        addLine(from: .rightElbow, to: .rightWrist)
        addLine(from: .leftShoulder, to: .rightShoulder)

        DispatchQueue.main.async { self.skeletonLines = newLines }
    }

    private func computeElbowAngle(from observation: VNHumanBodyPoseObservation) -> Double? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }
        var armAngles: [Double] = []
        if let ls = point(.leftShoulder, from: points), let le = point(.leftElbow, from: points), let lw = point(.leftWrist, from: points),
           let angle = angleDegrees(a: ls, b: le, c: lw) { armAngles.append(angle) }
        if let rs = point(.rightShoulder, from: points), let re = point(.rightElbow, from: points), let rw = point(.rightWrist, from: points),
           let angle = angleDegrees(a: rs, b: re, c: rw) { armAngles.append(angle) }
        return armAngles.isEmpty ? nil : armAngles.reduce(0, +) / Double(armAngles.count)
    }

    private func point(_ joint: VNHumanBodyPoseObservation.JointName, from recognizedPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> CGPoint? {
        guard let candidate = recognizedPoints[joint], candidate.confidence >= confidenceThreshold else { return nil }
        return CGPoint(x: candidate.x, y: candidate.y)
    }

    private func angleDegrees(a: CGPoint, b: CGPoint, c: CGPoint) -> Double? {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y), v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let v1L = sqrt(v1.dx * v1.dx + v1.dy * v1.dy), v2L = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        guard v1L > 0.001, v2L > 0.001 else { return nil }
        let dot = (v1.dx * v2.dx) + (v1.dy * v2.dy)
        return acos(max(-1.0, min(1.0, dot / (v1L * v2L)))) * 180.0 / Double.pi
    }

    private func processSmoothedAngle(_ angle: Double) {
        angleWindow.append(angle)
        if angleWindow.count > maxWindowSize { angleWindow.removeFirst() }
        let smoothAngle = angleWindow.reduce(0, +) / Double(angleWindow.count)
        DispatchQueue.main.async { self.smoothedElbowAngle = smoothAngle }

        let now = Date()
        switch repPhase {
        case .up:
            if smoothAngle <= downAngleThreshold {
                repPhase = .down
                downStartDate = now
            }
        case .down:
            if smoothAngle >= upAngleThreshold {
                let hold = now.timeIntervalSince(downStartDate ?? now)
                let interval = now.timeIntervalSince(lastRepDate)
                repPhase = .up
                downStartDate = nil
                if hold >= minDownHold && interval >= minRepInterval {
                    lastRepDate = now
                    DispatchQueue.main.async {
                        self.pushUpCount += 1
                        self.earnedMinutes = self.pushUpCount / 5
                    }
                }
            }
        }
    }
}

extension PushUpDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ o: AVCaptureOutput, didOutput s: CMSampleBuffer, from c: AVCaptureConnection) {
        analyze(sampleBuffer: s)
    }
}
