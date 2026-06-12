#if os(macOS)
@preconcurrency import AVFoundation
#endif
import Foundation

public protocol AudioLevelPreviewSession: AnyObject, Sendable {
    func stop()
}

public protocol AudioLevelPreviewSessionFactory: Sendable {
    func startPreview(
        deviceID: String,
        audioLevelMonitor: AudioLevelMonitor
    ) throws -> any AudioLevelPreviewSession
}

public struct DisabledAudioLevelPreviewSessionFactory: AudioLevelPreviewSessionFactory {
    public init() {}

    public func startPreview(
        deviceID: String,
        audioLevelMonitor: AudioLevelMonitor
    ) throws -> any AudioLevelPreviewSession {
        throw OpenRecError.microphoneUnavailable(deviceID)
    }
}

#if os(macOS)
public struct AVFoundationAudioLevelPreviewSessionFactory: AudioLevelPreviewSessionFactory {
    public init() {}

    public func startPreview(
        deviceID: String,
        audioLevelMonitor: AudioLevelMonitor
    ) throws -> any AudioLevelPreviewSession {
        guard let device = AVCaptureDevice.devices(for: .audio).first(where: { $0.uniqueID == deviceID }) else {
            throw OpenRecError.microphoneUnavailable(deviceID)
        }

        do {
            let session = AVCaptureSession()
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                throw OpenRecError.microphoneUnavailable(deviceID)
            }
            session.addInput(input)

            let output = AVCaptureAudioDataOutput()
            output.audioSettings = AVFoundationMicrophoneCaptureOutputSettings().audioSettings
            let activity = AudioLevelPreviewSessionActivity()
            let delegate = AVFoundationAudioLevelPreviewOutput(
                audioLevelMonitor: audioLevelMonitor,
                activity: activity
            )
            output.setSampleBufferDelegate(
                delegate,
                queue: DispatchQueue(label: "openrec.avfoundation.audio-level-preview")
            )
            guard session.canAddOutput(output) else {
                throw OpenRecError.microphoneUnavailable(deviceID)
            }
            session.addOutput(output)
            session.startRunning()

            return AVFoundationAudioLevelPreviewSession(
                session: session,
                outputDelegate: delegate,
                activity: activity
            )
        } catch let error as OpenRecError {
            throw error
        } catch {
            throw OpenRecError.microphoneUnavailable(deviceID)
        }
    }
}

final class AudioLevelPreviewSessionActivity: @unchecked Sendable {
    private let lock = NSLock()
    private var active = true

    var isActive: Bool {
        lock.withLock { active }
    }

    func deactivate() {
        lock.withLock {
            active = false
        }
    }
}

private final class AVFoundationAudioLevelPreviewOutput: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let audioLevelMonitor: AudioLevelMonitor
    private let activity: AudioLevelPreviewSessionActivity

    init(
        audioLevelMonitor: AudioLevelMonitor,
        activity: AudioLevelPreviewSessionActivity
    ) {
        self.audioLevelMonitor = audioLevelMonitor
        self.activity = activity
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard activity.isActive else { return }
        guard let snapshot = AudioSampleBufferLevelReader.measure(sampleBuffer) else {
            return
        }

        audioLevelMonitor.update(snapshot)
    }
}

private final class AVFoundationAudioLevelPreviewSession: AudioLevelPreviewSession, @unchecked Sendable {
    private let session: AVCaptureSession
    private let outputDelegate: AVFoundationAudioLevelPreviewOutput
    private let activity: AudioLevelPreviewSessionActivity

    init(
        session: AVCaptureSession,
        outputDelegate: AVFoundationAudioLevelPreviewOutput,
        activity: AudioLevelPreviewSessionActivity
    ) {
        self.session = session
        self.outputDelegate = outputDelegate
        self.activity = activity
    }

    func stop() {
        activity.deactivate()
        session.stopRunning()
        _ = outputDelegate
    }
}
#else
public typealias AVFoundationAudioLevelPreviewSessionFactory = DisabledAudioLevelPreviewSessionFactory
#endif
