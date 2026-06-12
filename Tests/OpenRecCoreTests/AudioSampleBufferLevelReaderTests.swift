import CoreMedia
import Foundation
import Testing
@testable import OpenRecCore

@Test func audioSampleBufferLevelReaderMeasuresFloat32PCM() throws {
    let sampleBuffer = try audioSampleBuffer(
        samples: [Float(0.5), Float(-0.5), Float(0.5), Float(-0.5)],
        formatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
        bytesPerSample: MemoryLayout<Float>.size
    )

    let snapshot = AudioSampleBufferLevelReader.measure(sampleBuffer)

    #expect(snapshot != nil)
    #expect(snapshot?.rmsDBFS ?? -80 > -7)
    #expect(snapshot?.rmsDBFS ?? -80 < -5)
    #expect(snapshot?.peakDBFS ?? -80 > -7)
    #expect(snapshot?.peakDBFS ?? -80 < -5)
    #expect(snapshot?.state == .normal)
}

@Test func audioSampleBufferLevelReaderMeasuresSignedInt16PCM() throws {
    let sampleBuffer = try audioSampleBuffer(
        samples: [Int16(16_384), Int16(-16_384), Int16(16_384), Int16(-16_384)],
        formatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        bytesPerSample: MemoryLayout<Int16>.size
    )

    let snapshot = AudioSampleBufferLevelReader.measure(sampleBuffer)

    #expect(snapshot != nil)
    #expect(snapshot?.rmsDBFS ?? -80 > -7)
    #expect(snapshot?.rmsDBFS ?? -80 < -5)
    #expect(snapshot?.state == .normal)
}

@Test func audioSampleBufferLevelReaderIgnoresUnsupportedBuffers() throws {
    let sampleBuffer = try emptySampleBuffer()

    #expect(AudioSampleBufferLevelReader.measure(sampleBuffer) == nil)
}

@Test func audioSampleBufferLevelReaderIgnoresBigEndianPCM() throws {
    let sampleBuffer = try audioSampleBuffer(
        samples: [Int16(16_384), Int16(-16_384)],
        formatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsBigEndian,
        bytesPerSample: MemoryLayout<Int16>.size
    )

    #expect(AudioSampleBufferLevelReader.measure(sampleBuffer) == nil)
}

private func audioSampleBuffer<Sample>(
    samples: [Sample],
    formatFlags: AudioFormatFlags,
    bytesPerSample: Int
) throws -> CMSampleBuffer {
    let data = samples.withUnsafeBufferPointer { buffer in
        Data(buffer: UnsafeBufferPointer(start: buffer.baseAddress, count: samples.count))
    }
    let sampleCount = samples.count
    var streamDescription = AudioStreamBasicDescription(
        mSampleRate: 48_000,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: formatFlags,
        mBytesPerPacket: UInt32(bytesPerSample),
        mFramesPerPacket: 1,
        mBytesPerFrame: UInt32(bytesPerSample),
        mChannelsPerFrame: 1,
        mBitsPerChannel: UInt32(bytesPerSample * 8),
        mReserved: 0
    )

    var formatDescription: CMAudioFormatDescription?
    let formatStatus = CMAudioFormatDescriptionCreate(
        allocator: kCFAllocatorDefault,
        asbd: &streamDescription,
        layoutSize: 0,
        layout: nil,
        magicCookieSize: 0,
        magicCookie: nil,
        extensions: nil,
        formatDescriptionOut: &formatDescription
    )
    guard formatStatus == noErr, let formatDescription else {
        throw OpenRecError.writerFailed("Could not create test audio format description.")
    }

    var blockBuffer: CMBlockBuffer?
    let blockStatus = CMBlockBufferCreateWithMemoryBlock(
        allocator: kCFAllocatorDefault,
        memoryBlock: nil,
        blockLength: data.count,
        blockAllocator: kCFAllocatorDefault,
        customBlockSource: nil,
        offsetToData: 0,
        dataLength: data.count,
        flags: 0,
        blockBufferOut: &blockBuffer
    )
    guard blockStatus == noErr, let blockBuffer else {
        throw OpenRecError.writerFailed("Could not create test audio block buffer.")
    }
    try data.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else {
            throw OpenRecError.writerFailed("Could not read test audio data.")
        }
        let replaceStatus = CMBlockBufferReplaceDataBytes(
            with: baseAddress,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: data.count
        )
        guard replaceStatus == noErr else {
            throw OpenRecError.writerFailed("Could not fill test audio block buffer.")
        }
    }

    var timing = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: 48_000),
        presentationTimeStamp: .zero,
        decodeTimeStamp: .invalid
    )
    var sampleBuffer: CMSampleBuffer?
    let sampleStatus = CMSampleBufferCreateReady(
        allocator: kCFAllocatorDefault,
        dataBuffer: blockBuffer,
        formatDescription: formatDescription,
        sampleCount: sampleCount,
        sampleTimingEntryCount: 1,
        sampleTimingArray: &timing,
        sampleSizeEntryCount: 1,
        sampleSizeArray: [bytesPerSample],
        sampleBufferOut: &sampleBuffer
    )
    guard sampleStatus == noErr, let sampleBuffer else {
        throw OpenRecError.writerFailed("Could not create test audio sample buffer.")
    }

    return sampleBuffer
}

private func emptySampleBuffer() throws -> CMSampleBuffer {
    var sampleBuffer: CMSampleBuffer?
    let status = CMSampleBufferCreate(
        allocator: kCFAllocatorDefault,
        dataBuffer: nil,
        dataReady: true,
        makeDataReadyCallback: nil,
        refcon: nil,
        formatDescription: nil,
        sampleCount: 0,
        sampleTimingEntryCount: 0,
        sampleTimingArray: nil,
        sampleSizeEntryCount: 0,
        sampleSizeArray: nil,
        sampleBufferOut: &sampleBuffer
    )

    guard status == noErr, let sampleBuffer else {
        throw OpenRecError.writerFailed("Could not create empty test sample buffer.")
    }

    return sampleBuffer
}
