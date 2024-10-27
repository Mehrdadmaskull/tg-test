//
//  HLSStreamManager.swift
//  tg-test
//
//  Created by Mehrdad Ahmadi on 2024-10-20.
//

import Foundation
import UIKit

// MARK: - Facade: HLSStreamManager
/// The main class for managing HLS video playback.
/// Acts as a Facade, coordinating playlist fetching, segment downloading,
/// video decoding, rendering, and quality adjustment.
class HLSStreamManager {
    private let playlistFetcher: PlaylistFetcher
    private let segmentDownloader: SegmentDownloader
    private let videoDecoder: VideoDecoder
    private let renderer: MetalRenderer
    private let networkMonitor: NetworkMonitor
    private let qualitySelector: QualitySelector
    
    init(view: UIView, playlistURL: URL, availableQualityLevels: [URL]) {
        // Initialize components
        self.renderer = MetalRenderer(view: view)
        self.playlistFetcher = PlaylistFetcher()
        self.segmentDownloader = SegmentDownloader()
        self.videoDecoder = VideoDecoder(renderer: renderer)
        self.qualitySelector = QualitySelector(qualityLevels: availableQualityLevels)
        self.networkMonitor = NetworkMonitor()
        
        // Handle bandwidth changes and low battery adjustments
        networkMonitor.onBandwidthChange = { [weak self] bandwidth in
            self?.qualitySelector.adjustQuality(basedOnBandwidth: bandwidth)
            self?.startPlayback()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleLowBattery), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        
        // Start initial playback
        self.startPlayback(with: playlistURL)
    }
    
    /// Respond to low battery levels by lowering quality.
    @objc private func handleLowBattery() {
        if UIDevice.current.batteryLevel < 0.2 {
            qualitySelector.setLowBatteryQuality()
        }
    }
    
    /// Begins or restarts playback at the current quality level.
    func startPlayback(with url: URL? = nil) {
        let currentURL = url ?? qualitySelector.getCurrentQualityURL()
        playlistFetcher.fetchPlaylist(url: currentURL) { [weak self] segmentURLs in
            guard let self = self else { return }
            self.segmentDownloader.downloadSegments(urls: segmentURLs) { segmentData in
                self.videoDecoder.decode(segmentData: segmentData)
            }
        }
    }
}
