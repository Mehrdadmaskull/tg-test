//
//  NetworkMonitor.swift
//  tg-test
//
//  Created by Mehrdad Ahmadi on 2024-10-21.
//

import Foundation

// MARK: - NetworkMonitor
class NetworkMonitor {
    var onBandwidthChange: ((Int) -> Void)?
    
    func monitorBandwidth() {
        // Simulate bandwidth changes for example purposes
        let simulatedBandwidth = Int.random(in: 300...2000)
        onBandwidthChange?(simulatedBandwidth)
    }
}
