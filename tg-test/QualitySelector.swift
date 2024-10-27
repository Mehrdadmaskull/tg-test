//
//  QualitySelector.swift
//  tg-test
//
//  Created by Mehrdad Ahmadi on 2024-10-25.
//

import Foundation

// MARK: - QualitySelector
class QualitySelector {
    private let qualityLevels: [URL]
    private var currentQualityIndex = 0
    private let switchThreshold: Int = 500 // A small buffer threshold to avoid frequent switching

    
    init(qualityLevels: [URL]) {
        self.qualityLevels = qualityLevels
    }
    
    func adjustQuality(basedOnBandwidth bandwidth: Int) {
        let targetIndex = (bandwidth < 500) ? 0 : (bandwidth < 1500) ? 1 : 2
        if abs(targetIndex - currentQualityIndex) >= switchThreshold {
            currentQualityIndex = targetIndex
        }
    }
    
    func getCurrentQualityURL() -> URL {
        return qualityLevels[currentQualityIndex]
    }
    
    func setQualityManually(index: Int) {
        guard index < qualityLevels.count else { return }
        currentQualityIndex = index
    }
    
    func setLowBatteryQuality() {
        currentQualityIndex = max(0, currentQualityIndex - 1)
    }
}
