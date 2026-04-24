import Foundation
import AVFoundation
import Vision
import CoreGraphics

final class PushUpDetector: NSObject, ObservableObject {
    @Published private(set) var pushUpCount = 0
    @Published private(set) var earnedMinutes = 0
    @Published private(set) var permissionDenied = false
    @Published private(set) var isRunning = false
    @Published private(set) var smoothedElbowAngle: Double = 180


    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.example.unrott.camera-session")
    private let visionQueue = DispatchQueue(label: "com.example.unrott.vision-queue")
    private let videoOutput = AVCaptureVideoDataOutput()

    private var isConfigured = false

    private enum RepPhase {
        case up
        case down
    }

    private var repPhase: RepPhase = .up
    private var downStartDate: Date?
    private var lastRepDate = Date.distantPast
    private var angleWindow: [Double] = []

    private let maxWindowSize = 6
    private let downAngleThreshold = 100.0
    private let upAngleThreshold = 155.0
    private let minDownHold: TimeInterval = 0.15
    private let minRepInterval: TimeInterval = 0.5
    private let confidenceThreshold: VNConfidence = 0.35

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            permissionDenied = false
            prepareAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.permissionDenied = !granted
                }
                if granted {
                    self.prepareAndStartSession()
                }
            }
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func resetCounters() {
        DispatchQueue.main.async {
            self.pushUpCount = 0
            self.earnedMinutes = 0
            self.smoothedElbowAngle = 180
        }

        visionQueue.async { [weak self] in
            guard let self else { return }
            self.repPhase = .up
            self.downStartDate = nil
            self.lastRepDate = Date.distantPast
            self.angleWindow.removeAll()
        }
    }

    private func prepareAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                self.configureSession()
            }

            guard self.isConfigured else {
                DispatchQueue.main.async {
                    self.permissionDenied = true
                }
                return
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        guard let camera else {
            isConfigured = false
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else {
            isConfigured = false
            return
        }

        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            isConfigured = false
            return
        }

        videoOutput.connection(with: .video)?.videoOrientation = .portrait

        isConfigured = true
    }

    private func analyze(sampleBuffer: CMSampleBuffer) {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                return
            }

            guard let elbowAngle = computeElbowAngle(from: observation) else {
                return
            }

            processSmoothedAngle(elbowAngle)
        } catch {
            return
        }
    }

    private func computeElbowAngle(from observation: VNHumanBodyPoseObservation) -> Double? {
        guard let points = try? observation.recognizedPoints(.all) else {
            return nil
        }

        var armAngles: [Double] = []

        if let leftShoulder = point(.leftShoulder, from: points),
           let leftElbow = point(.leftElbow, from: points),
           let leftWrist = point(.leftWrist, from: points),
           let angle = angleDegrees(a: leftShoulder, b: leftElbow, c: leftWrist) {
            armAngles.append(angle)
        }

        if let rightShoulder = point(.rightShoulder, from: points),
           let rightElbow = point(.rightElbow, from: points),
           let rightWrist = point(.rightWrist, from: points),
           let angle = angleDegrees(a: rightShoulder, b: rightElbow, c: rightWrist) {
            armAngles.append(angle)
        }

        guard !armAngles.isEmpty else {
            return nil
        }

        return armAngles.reduce(0, +) / Double(armAngles.count)
    }

    private func point(
        _ joint: VNHumanBodyPoseObservation.JointName,
        from recognizedPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    ) -> CGPoint? {
        guard let candidate = recognizedPoints[joint], candidate.confidence >= confidenceThreshold else {
            return nil
        }

        return CGPoint(x: candidate.x, y: candidate.y)
    }

    private func angleDegrees(a: CGPoint, b: CGPoint, c: CGPoint) -> Double? {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)

        let v1Length = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let v2Length = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)

        guard v1Length > 0.001, v2Length > 0.001 else {
            return nil
        }

        let dotProduct = (v1.dx * v2.dx) + (v1.dy * v2.dy)
        let cosine = max(-1.0, min(1.0, dotProduct / (v1Length * v2Length)))
        return acos(cosine) * 180.0 / .pi
    }

    private func processSmoothedAngle(_ angle: Double) {
        angleWindow.append(angle)
        if angleWindow.count > maxWindowSize {
            angleWindow.removeFirst()
        }

        let smoothAngle = angleWindow.reduce(0, +) / Double(angleWindow.count)
        DispatchQueue.main.async {
            self.smoothedElbowAngle = smoothAngle
        }

        let now = Date()

        switch repPhase {
        case .up:
            if smoothAngle <= downAngleThreshold {
                repPhase = .down
                downStartDate = now
            }
        case .down:
            guard smoothAngle >= upAngleThreshold else {
                return
            }

            let holdDuration = now.timeIntervalSince(downStartDate ?? now)
            let repDuration = now.timeIntervalSince(lastRepDate)

            repPhase = .up
            downStartDate = nil

            guard holdDuration >= minDownHold, repDuration >= minRepInterval else {
                return
            }

            lastRepDate = now
            DispatchQueue.main.async {
                self.pushUpCount += 1
                self.earnedMinutes = self.pushUpCount / 5
            }
        }
    }
}

extension PushUpDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        analyze(sampleBuffer: sampleBuffer)
    }
}
