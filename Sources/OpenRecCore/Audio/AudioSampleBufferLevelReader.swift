import CoreMedia
import Foundation

public enum AudioSampleBufferLevelReader {
    public static func measure(_ sampleBuffer: CMSampleBuffer) -> AudioLevelSnapshot? {
        guard let samples = samples(from: sampleBuffer), !samples.isEmpty else {
            return nil
        }

        return AudioLevelMeter.measure(samples: samples)
    }

    static func samples(from sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescriptionPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        let streamDescription = streamDescriptionPointer.pointee
        guard streamDescription.mFormatID == kAudioFormatLinearPCM else {
            return nil
        }

        var bufferListSize = 0
        var sizingBlockBuffer: CMBlockBuffer?
        let sizingStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &bufferListSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &sizingBlockBuffer
        )
        guard sizingStatus == noErr, bufferListSize > 0 else {
            return nil
        }

        let rawBufferList = UnsafeMutableRawPointer.allocate(
            byteCount: bufferListSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawBufferList.deallocate() }

        let audioBufferList = rawBufferList.assumingMemoryBound(to: AudioBufferList.self)
        var retainedBlockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList,
            bufferListSize: bufferListSize,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &retainedBlockBuffer
        )
        guard status == noErr else {
            return nil
        }

        return samples(from: audioBufferList, streamDescription: streamDescription)
    }

    static func samples(
        from audioBufferList: UnsafePointer<AudioBufferList>,
        streamDescription: AudioStreamBasicDescription
    ) -> [Float]? {
        let flags = streamDescription.mFormatFlags
        let bitsPerChannel = Int(streamDescription.mBitsPerChannel)
        let bytesPerSample = bitsPerChannel / 8
        guard bytesPerSample > 0 else {
            return nil
        }
        guard flags & kAudioFormatFlagIsBigEndian == 0 else {
            return nil
        }

        let isFloat = flags & kAudioFormatFlagIsFloat != 0
        let isSignedInteger = flags & kAudioFormatFlagIsSignedInteger != 0
        let isSupportedFloat = isFloat && bitsPerChannel == 32
        let isSupportedInt16 = isSignedInteger && bitsPerChannel == 16
        guard isSupportedFloat || isSupportedInt16 else {
            return nil
        }

        var samples: [Float] = []
        let buffers = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: audioBufferList)
        )
        for buffer in buffers {
            guard let data = buffer.mData else {
                continue
            }

            let sampleCount = Int(buffer.mDataByteSize) / bytesPerSample
            guard sampleCount > 0 else {
                continue
            }

            if isSupportedFloat {
                let typedData = data.assumingMemoryBound(to: Float.self)
                for index in 0..<sampleCount {
                    samples.append(typedData[index])
                }
            } else if isSupportedInt16 {
                let typedData = data.assumingMemoryBound(to: Int16.self)
                for index in 0..<sampleCount {
                    samples.append(Float(typedData[index]) / Float(Int16.max))
                }
            }
        }

        return samples.isEmpty ? nil : samples
    }
}
