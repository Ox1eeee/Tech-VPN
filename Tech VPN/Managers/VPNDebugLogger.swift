//
//  VPNDebugLogger.swift
//  Tech VPN
//
//  Debug logger for remote TestFlight debugging
//

import Foundation
import Combine
import NetworkExtension

class VPNDebugLogger: ObservableObject {
    static let shared = VPNDebugLogger()
    
    @Published var logs: [LogEntry] = []
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let level: Level
        
        enum Level: String {
            case info = "INFO"
            case error = "ERROR"
            case warning = "WARN"
        }
        
        var formatted: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return "[\(formatter.string(from: timestamp))] [\(level.rawValue)] \(message)"
        }
    }
    
    private init() {}
    
    func log(_ message: String, level: LogEntry.Level = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level)
        DispatchQueue.main.async {
            self.logs.append(entry)
            // Keep last 100 entries
            if self.logs.count > 100 {
                self.logs.removeFirst()
            }
        }
        print("[VPNDebug] [\(level.rawValue)] \(message)")
    }
    
    func error(_ message: String) {
        log(message, level: .error)
    }
    
    func warn(_ message: String) {
        log(message, level: .warning)
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
    
    /// Get all logs as a single string for sharing
    var allLogsText: String {
        logs.map { $0.formatted }.joined(separator: "\n")
    }
    
    /// Log current VPN configuration details
    func logVPNConfig() {
        let manager = NEVPNManager.shared()
        manager.loadFromPreferences { [weak self] error in
            if let error = error {
                self?.error("Load config failed: \(error.localizedDescription)")
                return
            }
            
            if let proto = manager.protocolConfiguration as? NEVPNProtocolIKEv2 {
                self?.log("--- VPN Configuration ---")
                self?.log("Server Address: \(proto.serverAddress ?? "nil")")
                self?.log("Remote Identifier: \(proto.remoteIdentifier ?? "nil")")
                self?.log("Local Identifier: \(proto.localIdentifier ?? "nil")")
                self?.log("Username: \(proto.username ?? "nil")")
                self?.log("Auth Method: \(proto.authenticationMethod.rawValue)")
                self?.log("Extended Auth (EAP): \(proto.useExtendedAuthentication)")
                self?.log("Certificate Type: \(proto.certificateType.rawValue)")
                self?.log("Password Ref: \(proto.passwordReference != nil ? "SET (\(proto.passwordReference!.count) bytes)" : "NIL")")
                self?.log("Cert Issuer CN: \(proto.serverCertificateIssuerCommonName ?? "not set")")
                self?.log("MOBIKE: \(!proto.disableMOBIKE)")
                self?.log("Disconnect on Sleep: \(proto.disconnectOnSleep)")
                self?.log("Manager Enabled: \(manager.isEnabled)")
                self?.log("Connection Status: \(self?.statusString(manager.connection.status) ?? "unknown")")
                self?.log("--- End Config ---")
            } else {
                self?.warn("No IKEv2 protocol configuration found")
            }
        }
    }
    
    private func statusString(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid: return "invalid"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "reasserting"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown"
        }
    }
}
