//
//  VideoDecoder.swift
//  tg-test
//
//  Created by Mehrdad Ahmadi on 2024-10-23.
//

import Foundation
import VideoToolbox
import CoreMedia

enum SampleBufferError: Error {
    case invalidNALUnits
    case missingSPSOrPPS
    case formatDescriptionCreationFailed(OSStatus)
    case blockBufferCreationFailed(OSStatus)
    case sampleBufferCreationFailed(OSStatus)
}

// MARK: - VideoDecoder
/// Decodes H.264 video frames into renderable images using VideoToolbox.
class VideoDecoder {
    private let renderer: MetalRenderer
    private let decodingQueue = DispatchQueue(label: "VideoDecodingQueue", qos: .userInitiated)
    
    init(renderer: MetalRenderer) {
        self.renderer = renderer
    }
    
    /// Decodes a video segment asynchronously and passes it to the renderer.
    func decode(segmentData: Data) {
        // Decode and render
        decodingQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                if let sampleBuffer = try self.createSampleBuffer(data: segmentData) {
                    self.decodeWithVideoToolbox(buffer: sampleBuffer)
                }
            } catch {
                print("Error creating sample buffer: \(error)")
            }
        }
    }
    
    /// Creates a CMSampleBuffer from raw H.264 data.
    private func createSampleBuffer(data: Data) throws -> CMSampleBuffer? {
        // Separate NAL units from the data
        let nalUnits = parseNALUnits(from: data)
        
        guard !nalUnits.isEmpty else {
            throw SampleBufferError.invalidNALUnits
        }
        
        // Extract SPS and PPS for CMFormatDescription
        guard let spsNAL = nalUnits.first(where: { $0[0] & 0x1F == 7 }), // SPS NAL units start with 0x67
              let ppsNAL = nalUnits.first(where: { $0[0] & 0x1F == 8 }) else {
            throw SampleBufferError.missingSPSOrPPS
        }

        var formatDescription: CMFormatDescription?

        // Convert `spsNAL` and `ppsNAL` to UnsafePointer
        let parameterSetPointers: [UnsafePointer<UInt8>] = [spsNAL, ppsNAL].map { data in
            data.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) }
        }

        let parameterSetSizes = [spsNAL.count, ppsNAL.count]

        let formatStatus = CMVideoFormatDescriptionCreateFromH264ParameterSets(
            allocator: kCFAllocatorDefault,
            parameterSetCount: 2,
            parameterSetPointers: parameterSetPointers,
            parameterSetSizes: parameterSetSizes,
            nalUnitHeaderLength: 4,
            formatDescriptionOut: &formatDescription
        )

        guard formatStatus == noErr, let validFormatDescription = formatDescription else {
            throw SampleBufferError.formatDescriptionCreationFailed(formatStatus)
        }
        
        // Wrap the NAL units in a CMBlockBuffer
        var blockBuffer: CMBlockBuffer?
        let dataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        data.copyBytes(to: dataPointer, count: data.count)
        
        let blockStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: dataPointer,
            blockLength: data.count,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: data.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard blockStatus == kCMBlockBufferNoErr, let validBlockBuffer = blockBuffer else {
            dataPointer.deallocate()
            throw SampleBufferError.blockBufferCreationFailed(blockStatus)
        }
        
        // Create CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        let sampleSizes: [Int] = [data.count]
        
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: validBlockBuffer,
            formatDescription: validFormatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: sampleSizes.count,
            sampleSizeArray: sampleSizes,
            sampleBufferOut: &sampleBuffer
        )
        
        if sampleStatus != noErr {
            throw SampleBufferError.sampleBufferCreationFailed(sampleStatus)
        }
        
        return sampleBuffer
    }

    // Helper function to parse NAL units from raw H.264 data
    private func parseNALUnits(from data: Data) -> [Data] {
        var nalUnits: [Data] = []
        var start = 0
        
        while start < data.count {
            if let nalStart = data[start...].firstIndex(of: 0x00),
               let nalEnd = data[(nalStart + 1)...].firstIndex(of: 0x01) {
                let nalUnit = data[nalStart...nalEnd]
                nalUnits.append(nalUnit)
                start = nalEnd + 1
            } else {
                break
            }
        }
        return nalUnits
    }
    
    /// Sends a CMSampleBuffer to VideoToolbox for decoding.
    private func decodeWithVideoToolbox(buffer: CMSampleBuffer) {
        // Decoding and passing the buffer to the renderer
        if let imageBuffer = CMSampleBufferGetImageBuffer(buffer) {
            renderer.render(pixelBuffer: imageBuffer)
        }
    }
}
