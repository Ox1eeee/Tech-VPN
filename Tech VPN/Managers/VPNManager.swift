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
    private var connectionId: Int?
    
    private let vpnManager = NEVPNManager.shared()
    private let keychain = KeychainHelper.shared
    
    init() {
        loadVPNConfiguration()
        monitorVPNStatus()
    }
    
    // MARK: - Configure IKEv2 VPN
    func configureVPN(server: VPNServer, config: VPNServerConfig, username: String, password: String) {
        // Save VPN server credentials to Keychain with VPN-accessible protection
        keychain.saveForVPN(string: password, forKey: KeychainHelper.vpnServerPasswordKey)
        keychain.saveForVPN(string: username, forKey: KeychainHelper.vpnServerUsernameKey)
        
        // Get persistent reference AFTER saving
        guard let passwordRef = keychain.persistentReference(forKey: KeychainHelper.vpnServerPasswordKey) else {
            print("Failed to get VPN password persistent reference from Keychain")
            return
        }
        
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
        
        vpnManager.saveToPreferences { [weak self] error in
            if let error = error {
                print("Failed to save VPN configuration: \(error.localizedDescription)")
                return
            }
            print("VPN configuration saved successfully for server: \(config.serverAddress)")
            // Must reload after first save
            self?.vpnManager.loadFromPreferences { error in
                if let error = error {
                    print("Failed to reload after save: \(error.localizedDescription)")
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
        loadVPNConfiguration()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            do {
                try self?.vpnManager.connection.startVPNTunnel()
                DispatchQueue.main.async {
                    self?.status = .connecting
                }
                // Log connection to backend
                self?.logConnection()
            } catch {
                print("Failed to start VPN tunnel: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.status = .disconnected
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
        updateConnectionStatus()
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
        Task {
            do {
                let response: ConnectionLogResponse = try await APIService.shared.logConnection(serverId: serverId)
                await MainActor.run {
                    self.connectionId = response.connectionId
                }
            } catch {
                print("Failed to log connection: \(error.localizedDescription)")
            }
        }
    }
    
    private func logDisconnection() {
        guard let connId = connectionId else { return }
        Task {
            do {
                try await APIService.shared.logDisconnection(connectionId: connId)
                await MainActor.run {
                    self.connectionId = nil
                }
            } catch {
                print("Failed to log disconnection: \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
