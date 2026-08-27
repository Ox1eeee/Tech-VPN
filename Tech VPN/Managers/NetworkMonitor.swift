//
//  NetworkMonitor.swift
//  Tech VPN
//
//  Created by Xylo on 25/08/26.
//

import Foundation
import Combine
import Darwin

/// Monitors network interface traffic on VPN tunnel (utun) interfaces.
/// Uses getifaddrs() to read cumulative byte counters and computes live speed.
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    @Published var downloadSpeed: Double = 0.0  // Mbps (smoothed)
    @Published var uploadSpeed: Double = 0.0    // Mbps (smoothed)
    @Published var totalBytesDown: Int64 = 0
    @Published var totalBytesUp: Int64 = 0
    @Published var sessionBytesDown: Int64 = 0
    @Published var sessionBytesUp: Int64 = 0
    @Published var speedHistory: [SpeedSample] = []
    @Published var sessionDuration: TimeInterval = 0 // seconds since monitoring started
    
    // MARK: - Internal State
    private var timer: Timer?
    private var previousBytesDown: Int64 = 0
    private var previousBytesUp: Int64 = 0
    private var sessionStartBytesDown: Int64 = 0
    private var sessionStartBytesUp: Int64 = 0
    private var isMonitoring = false
    private var monitoringStartDate: Date?
    private let maxHistorySamples = 60 // Keep last 60 seconds
    private var recentDownSpeeds: [Double] = [] // For rolling average
    private var recentUpSpeeds: [Double] = []
    private let smoothingWindow = 3 // Average over last 3 seconds
    
    struct SpeedSample: Identifiable {
        let id = UUID()
        let timestamp: Date
        let download: Double // Mbps
        let upload: Double   // Mbps
    }
    
    private init() {}
    
    /// Average speed for the current session in Mbps
    var sessionAverageSpeed: Double {
        guard sessionDuration > 0 else { return 0 }
        let totalBytes = Double(sessionBytesDown + sessionBytesUp)
        return totalBytes * 8.0 / 1_000_000.0 / sessionDuration
    }
    
    // MARK: - Start/Stop Monitoring
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Reset session counters
        let current = getInterfaceBytes()
        sessionStartBytesDown = current.bytesIn
        sessionStartBytesUp = current.bytesOut
        previousBytesDown = current.bytesIn
        previousBytesUp = current.bytesOut
        
        recentDownSpeeds = []
        recentUpSpeeds = []
        monitoringStartDate = Date()
        
        DispatchQueue.main.async {
            self.sessionBytesDown = 0
            self.sessionBytesUp = 0
            self.sessionDuration = 0
            self.downloadSpeed = 0.0
            self.uploadSpeed = 0.0
            self.speedHistory = []
        }
        
        // Poll every 1 second on the main run loop
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.sample()
            }
            RunLoop.main.add(self.timer!, forMode: .common)
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Sampling
    
    private func sample() {
        let current = getInterfaceBytes()
        
        let deltaDown = current.bytesIn - previousBytesDown
        let deltaUp = current.bytesOut - previousBytesUp
        
        // Convert bytes/sec to Mbps (megabits per second)
        let instantDl = Double(max(deltaDown, 0)) * 8.0 / 1_000_000.0
        let instantUl = Double(max(deltaUp, 0)) * 8.0 / 1_000_000.0
        
        previousBytesDown = current.bytesIn
        previousBytesUp = current.bytesOut
        
        // Rolling average for smoother display
        recentDownSpeeds.append(instantDl)
        recentUpSpeeds.append(instantUl)
        if recentDownSpeeds.count > smoothingWindow {
            recentDownSpeeds.removeFirst()
        }
        if recentUpSpeeds.count > smoothingWindow {
            recentUpSpeeds.removeFirst()
        }
        let avgDl = recentDownSpeeds.reduce(0, +) / Double(recentDownSpeeds.count)
        let avgUl = recentUpSpeeds.reduce(0, +) / Double(recentUpSpeeds.count)
        
        let sessionDown = current.bytesIn - sessionStartBytesDown
        let sessionUp = current.bytesOut - sessionStartBytesUp
        
        let speedSample = SpeedSample(timestamp: Date(), download: instantDl, upload: instantUl)
        
        let elapsed = Date().timeIntervalSince(monitoringStartDate ?? Date())
        
        DispatchQueue.main.async {
            self.downloadSpeed = avgDl
            self.uploadSpeed = avgUl
            self.totalBytesDown = current.bytesIn
            self.totalBytesUp = current.bytesOut
            self.sessionBytesDown = max(sessionDown, 0)
            self.sessionBytesUp = max(sessionUp, 0)
            self.sessionDuration = elapsed
            
            self.speedHistory.append(speedSample)
            if self.speedHistory.count > self.maxHistorySamples {
                self.speedHistory.removeFirst()
            }
        }
    }
    
    // MARK: - Read Network Interface Bytes
    
    /// Reads cumulative bytes in/out using getifaddrs().
    /// We read ALL active network interfaces (en0/WiFi, pdp_ip0/Cellular, utun/VPN tunnel).
    /// When VPN is active, all user traffic is tunneled, so the delta on physical interfaces
    /// reflects VPN throughput. We sum both physical + tunnel to be safe (and deduplicate
    /// by using only WiFi+Cellular which is the actual data consumed).
    private func getInterfaceBytes() -> (bytesIn: Int64, bytesOut: Int64) {
        var bytesIn: Int64 = 0
        var bytesOut: Int64 = 0
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddr) }
        
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = cursor {
            defer { cursor = addr.pointee.ifa_next }
            
            // Only process AF_LINK (data link layer) entries which have ifa_data
            guard let sa = addr.pointee.ifa_addr,
                  sa.pointee.sa_family == UInt8(AF_LINK) else {
                continue
            }
            
            let name = String(cString: addr.pointee.ifa_name)
            
            // Include: en (WiFi/Ethernet), pdp_ip (Cellular), utun (VPN tunnel), ipsec
            let tracked = name.hasPrefix("en") ||
                          name.hasPrefix("pdp_ip") ||
                          name.hasPrefix("utun") ||
                          name.hasPrefix("ipsec")
            
            if tracked, let data = addr.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self)
                bytesIn += Int64(networkData.pointee.ifi_ibytes)
                bytesOut += Int64(networkData.pointee.ifi_obytes)
            }
        }
        
        return (bytesIn, bytesOut)
    }
}
