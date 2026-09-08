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
    @Published var publicIP: String = ""
    @Published var killSwitchEnabled: Bool {
        didSet { UserDefaults.standard.set(killSwitchEnabled, forKey: "killSwitchEnabled") }
    }
    @Published var useFastestServer: Bool {
        didSet { UserDefaults.standard.set(useFastestServer, forKey: "useFastestServer") }
    }
    @Published var autoConnectEnabled: Bool {
        didSet { UserDefaults.standard.set(autoConnectEnabled, forKey: "autoConnectEnabled") }
    }
    /// Prevents auto-connect from firing after user manually disconnects within the same session
    private var userDidManuallyDisconnect = false
    private var connectionStartDate: Date?
    
    let networkMonitor = NetworkMonitor.shared
    
    private let vpnManager = NEVPNManager.shared()
    private let keychain = KeychainHelper.shared
    private let debugLog = VPNDebugLogger.shared
    
    init() {
        // Load persisted preferences (defaults: kill switch on, fastest server off)
        self.killSwitchEnabled = UserDefaults.standard.object(forKey: "killSwitchEnabled") as? Bool ?? false
        self.useFastestServer = UserDefaults.standard.object(forKey: "useFastestServer") as? Bool ?? false
        self.autoConnectEnabled = UserDefaults.standard.object(forKey: "autoConnectEnabled") as? Bool ?? false
        loadVPNConfiguration()
        monitorVPNStatus()
        fetchPublicIP()
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
        
        // Kill Switch: use On-Demand rules to auto-reconnect if VPN drops
        applyOnDemandRules()
        
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
    
    // MARK: - Kill Switch (On-Demand Rules)
    private func applyOnDemandRules() {
        if killSwitchEnabled {
            let connectRule = NEOnDemandRuleConnect()
            connectRule.interfaceTypeMatch = .any
            vpnManager.onDemandRules = [connectRule]
            vpnManager.isOnDemandEnabled = true
            debugLog.log("Kill Switch ON — on-demand rules applied")
        } else {
            vpnManager.onDemandRules = []
            vpnManager.isOnDemandEnabled = false
            debugLog.log("Kill Switch OFF — on-demand rules cleared")
        }
    }
    
    func updateKillSwitch(enabled: Bool) {
        killSwitchEnabled = enabled
        vpnManager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.debugLog.error("Failed to load prefs for kill switch update: \(error.localizedDescription)")
                return
            }
            self.applyOnDemandRules()
            self.vpnManager.saveToPreferences { error in
                if let error = error {
                    self.debugLog.error("Failed to save kill switch update: \(error.localizedDescription)")
                } else {
                    self.debugLog.log("Kill switch preference saved: \(enabled)")
                }
            }
        }
    }
    
    // MARK: - Server Persistence (for auto-connect)
    func persistSelectedServer() {
        guard let server = selectedServer else { return }
        UserDefaults.standard.set(server.id, forKey: "lastSelectedServerId")
        debugLog.log("Persisted selected server: \(server.name) (id: \(server.id))")
    }
    
    private func loadPersistedServerId() -> Int? {
        let val = UserDefaults.standard.object(forKey: "lastSelectedServerId") as? Int
        return val
    }
    
    // MARK: - Auto-Connect
    func autoConnectIfNeeded() {
        guard autoConnectEnabled else { return }
        guard !isConnected && status != .connecting else { return }
        guard !userDidManuallyDisconnect else {
            debugLog.log("Auto-connect skipped: user manually disconnected this session")
            return
        }
        
        debugLog.log("Auto-connect triggered")
        
        Task {
            do {
                let servers = try await APIService.shared.fetchServers()
                guard !servers.isEmpty else {
                    debugLog.log("Auto-connect: no servers available")
                    return
                }
                
                let targetServer: VPNServer?
                
                if useFastestServer {
                    debugLog.log("Auto-connect: finding fastest server...")
                    targetServer = await APIService.shared.findFastestServer(from: servers)
                } else if let lastId = loadPersistedServerId(),
                          let server = servers.first(where: { $0.id == lastId }) {
                    debugLog.log("Auto-connect: using last selected server: \(server.name)")
                    targetServer = server
                } else {
                    debugLog.log("Auto-connect: no persisted server, using first available")
                    targetServer = servers.first
                }
                
                guard let server = targetServer else { return }
                
                await MainActor.run {
                    selectedServer = server
                    persistSelectedServer()
                }
                
                let config = VPNServerConfig(
                    serverAddress: server.ipAddress,
                    remoteIdentifier: server.ipAddress,
                    certificate: nil,
                    presharedKey: nil
                )
                
                await MainActor.run {
                    // Use the embedded credentials
                    configureVPN(
                        server: server,
                        config: config,
                        username: "techvpn",
                        password: "TechVPN@2026!"
                    )
                    // Slight delay for config to save, then connect
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.connect()
                    }
                }
            } catch {
                debugLog.error("Auto-connect failed: \(error.localizedDescription)")
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
        userDidManuallyDisconnect = false
        debugLog.log("Connect requested...")
        loadVPNConfiguration()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Re-enable on-demand (kill switch) before connecting
            if self.killSwitchEnabled {
                self.vpnManager.isOnDemandEnabled = true
                self.applyOnDemandRules()
                self.vpnManager.saveToPreferences { _ in }
            }
            
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
        userDidManuallyDisconnect = true
        // Temporarily disable on-demand so iOS doesn't auto-reconnect after manual disconnect
        if killSwitchEnabled {
            vpnManager.isOnDemandEnabled = false
            vpnManager.saveToPreferences { [weak self] _ in
                self?.vpnManager.connection.stopVPNTunnel()
            }
        } else {
            vpnManager.connection.stopVPNTunnel()
        }
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
                    self.networkMonitor.startMonitoring()
                    self.fetchPublicIP()
                }
            case .connecting:
                self.status = .connecting
                self.isConnected = false
            case .disconnecting:
                self.status = .disconnecting
                self.isConnected = false
            case .disconnected:
                if self.connectedDate != nil {
                    // Was connected, now disconnected — stop monitor
                    self.networkMonitor.stopMonitoring()
                }
                self.status = .disconnected
                self.isConnected = false
                self.connectedDate = nil
                self.fetchPublicIP()
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
    
    // MARK: - Public IP
    private func fetchPublicIP() {
        Task {
            do {
                let url = URL(string: "https://api.ipify.org")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                await MainActor.run {
                    self.publicIP = ip
                }
            } catch {
                await MainActor.run {
                    self.publicIP = ""
                }
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
        let bytesSent = networkMonitor.sessionBytesUp
        let bytesReceived = networkMonitor.sessionBytesDown
        Task {
            do {
                try await APIService.shared.logDisconnection(
                    serverId: serverId,
                    durationSeconds: duration,
                    bytesSent: bytesSent,
                    bytesReceived: bytesReceived
                )
            } catch {
                print("Failed to log disconnection: \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
