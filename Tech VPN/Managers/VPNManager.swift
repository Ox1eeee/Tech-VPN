//
//  VPNManager.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import Foundation
import NetworkExtension
import SwiftUI
import Combine

class VPNManager: ObservableObject {
    @Published var status: VPNConnectionStatus = .disconnected
    @Published var isConnected: Bool = false
    @Published var selectedServer: VPNServer?
    @Published var connectedDate: Date?
    private var connectionStartDate: Date?
    
    private let vpnManager = NEVPNManager.shared()
    private let keychain = KeychainHelper.shared
    private let debugLog = VPNDebugLogger.shared
    
    init() {
        loadVPNConfiguration()
        monitorVPNStatus()
    }
    
    // MARK: - Configure IKEv2 VPN
    func configureVPN(server: VPNServer, config: VPNServerConfig, username: String, password: String) {
        debugLog.log("Configuring VPN for server: \(config.serverAddress)")
        debugLog.log("Remote Identifier: \(config.remoteIdentifier)")
        debugLog.log("Username: \(username)")
        
        // Save VPN server credentials to Keychain with VPN-accessible protection
        let passSaved = keychain.saveForVPN(string: password, forKey: KeychainHelper.vpnServerPasswordKey)
        let userSaved = keychain.saveForVPN(string: username, forKey: KeychainHelper.vpnServerUsernameKey)
        debugLog.log("Keychain save - password: \(passSaved), username: \(userSaved)")
        
        // Get persistent reference AFTER saving
        guard let passwordRef = keychain.persistentReference(forKey: KeychainHelper.vpnServerPasswordKey) else {
            debugLog.error("Failed to get VPN password persistent reference from Keychain")
            return
        }
        debugLog.log("Password ref obtained: \(passwordRef.count) bytes")
        
        let ikev2 = NEVPNProtocolIKEv2()
        
        // Server details
        ikev2.serverAddress = config.serverAddress
        ikev2.remoteIdentifier = config.remoteIdentifier
        ikev2.localIdentifier = username
        
        // Authentication (EAP-MSCHAPv2)
        ikev2.username = username
        ikev2.passwordReference = passwordRef
        ikev2.authenticationMethod = .none
        ikev2.useExtendedAuthentication = true
        
        // Certificate validation - trust system CAs (includes Let's Encrypt)
        // Server cert is RSA (--key-type rsa in certbot)
        ikev2.certificateType = .RSA
        
        // IKE security - match server ciphers
        ikev2.ikeSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256
        ikev2.ikeSecurityAssociationParameters.integrityAlgorithm = .SHA256
        ikev2.ikeSecurityAssociationParameters.diffieHellmanGroup = .group14
        ikev2.childSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256
        ikev2.childSecurityAssociationParameters.integrityAlgorithm = .SHA256
        ikev2.childSecurityAssociationParameters.diffieHellmanGroup = .group14
        
        // MOBIKE enabled (auto-reconnect on WiFi ↔ Cellular)
        ikev2.disableMOBIKE = false
        ikev2.enableRevocationCheck = false
        // Accept server-pushed DNS and internal IP subnet config (DNS leak protection handled server-side)
        ikev2.useConfigurationAttributeInternalIPSubnet = true
        
        // Always-on: don't disconnect on sleep
        ikev2.disconnectOnSleep = false
        
        // Save to VPN manager
        vpnManager.protocolConfiguration = ikev2
        vpnManager.localizedDescription = "Tech VPN"
        vpnManager.isEnabled = true
        vpnManager.isOnDemandEnabled = false
        
        debugLog.log("Saving VPN preferences...")
        vpnManager.saveToPreferences { [weak self] error in
            if let error = error {
                self?.debugLog.error("Failed to save VPN config: \(error.localizedDescription)")
                return
            }
            self?.debugLog.log("VPN config saved OK for: \(config.serverAddress)")
            // Must reload after first save
            self?.vpnManager.loadFromPreferences { error in
                if let error = error {
                    self?.debugLog.error("Failed to reload after save: \(error.localizedDescription)")
                } else {
                    self?.debugLog.log("VPN config reloaded successfully")
                }
            }
        }
    }
    
    // MARK: - Load VPN Configuration
    func loadVPNConfiguration() {
        vpnManager.loadFromPreferences { [weak self] error in
            if let error = error {
                print("Failed to load VPN preferences: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                self?.updateConnectionStatus()
            }
        }
    }
    
    // MARK: - Connect
    func connect() {
        debugLog.log("Connect requested...")
        loadVPNConfiguration()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.debugLog.log("Starting VPN tunnel...")
            do {
                try self.vpnManager.connection.startVPNTunnel()
                DispatchQueue.main.async {
                    self.status = .connecting
                }
                self.debugLog.log("startVPNTunnel() called successfully")
                // Log connection to backend
                self.logConnection()
            } catch {
                self.debugLog.error("startVPNTunnel() failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.status = .disconnected
                }
            }
        }
    }
    
    // MARK: - Disconnect
    func disconnect() {
        vpnManager.connection.stopVPNTunnel()
        DispatchQueue.main.async {
            self.connectedDate = nil
        }
        // Log disconnection to backend
        logDisconnection()
    }
    
    // MARK: - Toggle Connection
    func toggleConnection() {
        if isConnected {
            disconnect()
        } else {
            connect()
        }
    }
    
    // MARK: - Monitor Status
    private func monitorVPNStatus() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange),
            name: NSNotification.Name.NEVPNStatusDidChange,
            object: nil
        )
    }
    
    @objc private func vpnStatusDidChange() {
        let rawStatus = vpnManager.connection.status
        debugLog.log("VPN status changed: \(statusDescription(rawStatus))")
        updateConnectionStatus()
    }
    
    private func statusDescription(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid: return "INVALID (no VPN config)"
        case .disconnected: return "DISCONNECTED"
        case .connecting: return "CONNECTING"
        case .connected: return "CONNECTED"
        case .reasserting: return "REASSERTING"
        case .disconnecting: return "DISCONNECTING"
        @unknown default: return "UNKNOWN"
        }
    }
    
    private func updateConnectionStatus() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch self.vpnManager.connection.status {
            case .connected:
                self.status = .connected
                self.isConnected = true
                if self.connectedDate == nil {
                    self.connectedDate = Date()
                }
            case .connecting:
                self.status = .connecting
                self.isConnected = false
            case .disconnecting:
                self.status = .disconnecting
                self.isConnected = false
            case .disconnected:
                self.status = .disconnected
                self.isConnected = false
                self.connectedDate = nil
            case .invalid:
                self.status = .invalid
                self.isConnected = false
            case .reasserting:
                self.status = .connecting
                self.isConnected = false
            @unknown default:
                self.status = .unknown
                self.isConnected = false
            }
        }
    }
    
    // MARK: - Connection Logging
    private func logConnection() {
        guard let serverId = selectedServer?.id else { return }
        connectionStartDate = Date()
        Task {
            do {
                try await APIService.shared.logConnection(serverId: serverId)
            } catch {
                print("Failed to log connection: \(error.localizedDescription)")
            }
        }
    }
    
    private func logDisconnection() {
        guard let serverId = selectedServer?.id else { return }
        let duration = Int(Date().timeIntervalSince(connectionStartDate ?? Date()))
        Task {
            do {
                try await APIService.shared.logDisconnection(serverId: serverId, durationSeconds: duration)
            } catch {
                print("Failed to log disconnection: \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
