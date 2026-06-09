#if os(macOS)
@preconcurrency import AVFoundation
#endif
import Foundation

public protocol MicrophoneCaptureSession: AnyObject, Sendable {
    func stop() throws
}

public protocol MicrophoneCaptureSessionFactory: Sendable {
    func startMicrophoneCapture(
        deviceID: String,
        writer: any RecordingOutputWriter
    ) throws -> any MicrophoneCaptureSession
}

public struct DisabledMicrophoneCaptureSessionFactory: MicrophoneCaptureSessionFactory {
    public init() {}

    public func startMicrophoneCapture(
        deviceID: String,
        writer: any RecordingOutputWriter
    ) throws -> any MicrophoneCaptureSession {
        throw OpenRecError.microphoneUnavailable(deviceID)
    }
}

#if os(macOS)
public struct AVFoundationMicrophoneCaptureSessionFactory: MicrophoneCaptureSessionFactory {
    public init() {}

    public func startMicrophoneCapture(
        deviceID: String,
        writer: any RecordingOutputWriter
    ) throws -> any MicrophoneCaptureSession {
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
            let delegate = AVFoundationMicrophoneCaptureOutput(writer: writer)
            output.setSampleBufferDelegate(
                delegate,
                queue: DispatchQueue(label: "openrec.avfoundation.microphone")
            )
            guard session.canAddOutput(output) else {
                throw OpenRecError.microphoneUnavailable(deviceID)
            }
            session.addOutput(output)

            session.startRunning()

            return AVFoundationMicrophoneCaptureSession(session: session, outputDelegate: delegate)
        } catch let error as OpenRecError {
            throw error
        } catch {
            throw OpenRecError.microphoneUnavailable(deviceID)
        }
    }
}

struct AVFoundationMicrophoneCaptureOutputSettings {
    var audioSettings: [String: Any] {
        // AVCaptureAudioDataOutput on macOS normalizes away explicit sample-rate and
        // channel-count keys. The AVAssetWriter input owns the 48 kHz / stereo AAC encoding.
        [
            AVFormatIDKey: kAudioFormatLinearPCM
        ]
    }
}

private final class AVFoundationMicrophoneCaptureOutput: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let writer: any RecordingOutputWriter
    private let lock = NSLock()
    private var lastError: OpenRecError?

    init(writer: any RecordingOutputWriter) {
        self.writer = writer
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        do {
            try writer.appendAudioSampleBuffer(sampleBuffer)
        } catch let error as OpenRecError {
            setLastError(error)
        } catch {
            setLastError(.writerFailed(String(describing: error)))
        }
    }

    func takeLastError() -> OpenRecError? {
        lock.withLock {
            let error = lastError
            lastError = nil
            return error
        }
    }

    private func setLastError(_ error: OpenRecError) {
        lock.withLock {
            lastError = error
        }
    }
}

private final class AVFoundationMicrophoneCaptureSession: MicrophoneCaptureSession, @unchecked Sendable {
    private let session: AVCaptureSession
    private let outputDelegate: AVFoundationMicrophoneCaptureOutput

    init(
        session: AVCaptureSession,
        outputDelegate: AVFoundationMicrophoneCaptureOutput
    ) {
        self.session = session
        self.outputDelegate = outputDelegate
    }

    func stop() throws {
        session.stopRunning()

        if let error = outputDelegate.takeLastError() {
            throw error
        }
    }
}
#else
public typealias AVFoundationMicrophoneCaptureSessionFactory = DisabledMicrophoneCaptureSessionFactory
#endif
