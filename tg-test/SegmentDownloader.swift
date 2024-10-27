//
//  SegmentDownloader.swift
//  tg-test
//
//  Created by Mehrdad Ahmadi on 2024-10-20.
//

import Foundation

// MARK: - SegmentDownloader
/// Downloads video segments asynchronously and manages segment buffering.
class SegmentDownloader {
    private let downloadQueue = DispatchQueue(label: "SegmentDownloadQueue", attributes: .concurrent)
    private let maxBufferSize = 10 // Limit the number of segments in memory
    private var bufferedSegments: [Data] = []
    private let bufferLock = NSLock() // Thread-safe buffer access
    
    /// Downloads segments and buffers them up to maxBufferSize.
    func downloadSegments(urls: [URL], completion: @escaping (Data) -> Void) {
        downloadQueue.async {
            for url in urls {
                self.bufferLock.lock()
                defer { self.bufferLock.unlock() }
                guard self.bufferedSegments.count < self.maxBufferSize else { break }
                
                URLSession.shared.dataTask(with: url) { data, _, error in
                    if let data = data, error == nil {
                        self.bufferedSegments.append(data)
                        completion(data)
                    }
                }.resume()
            }
        }
    }
}
