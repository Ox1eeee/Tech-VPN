//
//  DebugLogView.swift
//  Tech VPN
//
//  Debug log view for remote TestFlight debugging
//

import SwiftUI

struct DebugLogView: View {
    @ObservedObject var logger = VPNDebugLogger.shared
    @ObservedObject var vpnManager: VPNManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("DEBUG LOG")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button("Copy") {
                        UIPasteboard.general.string = logger.allLogsText
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    
                    Button("Clear") {
                        logger.clear()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.leading, 12)
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 12)
                }
                .padding()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Log Config") {
                        logger.logVPNConfig()
                    }
                    .buttonStyle(DebugButtonStyle(color: .blue))
                    
                    Button("Test Connect") {
                        logger.log("Manual connect triggered")
                        vpnManager.connect()
                    }
                    .buttonStyle(DebugButtonStyle(color: .green))
                    
                    Button("Disconnect") {
                        vpnManager.disconnect()
                        logger.log("Manual disconnect triggered")
                    }
                    .buttonStyle(DebugButtonStyle(color: .red))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Server info
                VStack(alignment: .leading, spacing: 4) {
                    if let server = vpnManager.selectedServer {
                        Text("Server: \(server.name) (\(server.ipAddress))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Text("Status: \(vpnManager.status.rawValue)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(vpnManager.isConnected ? .green : .yellow)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                Divider().background(Color.gray.opacity(0.3))
                
                // Log entries
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(logger.logs) { entry in
                                Text(entry.formatted)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(colorForLevel(entry.level))
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: logger.logs.count) { _ in
                        if let last = logger.logs.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onAppear {
            logger.log("Debug view opened")
            logger.logVPNConfig()
        }
    }
    
    private func colorForLevel(_ level: VPNDebugLogger.LogEntry.Level) -> Color {
        switch level {
        case .info: return .white
        case .error: return .red
        case .warning: return .yellow
        }
    }
}

struct DebugButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}
