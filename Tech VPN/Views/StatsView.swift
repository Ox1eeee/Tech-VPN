//
//  StatsView.swift
//  Tech VPN
//
//  Created by Xylo on 20/03/26.
//

import SwiftUI
import Supabase

struct StatsView: View {
    @ObservedObject var vpnManager: VPNManager
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var usageStats: UsageStats?
    @State private var securityAudit: SecurityAudit?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                statsTopBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.Spacing.md) {
                        // Section Header
                        sectionHeader
                            .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        
                        // Data Usage Circle
                        dataUsageCard
                            .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        
                        // Speed Trends
                        speedTrendsCard
                            .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        
                        // Stats Grid
                        statsGrid
                            .padding(.horizontal, AppTheme.Spacing.safeMargin)
                        
                        // Security Audit
                        securityAuditCard
                            .padding(.horizontal, AppTheme.Spacing.safeMargin)
                            .padding(.bottom, 100)
                    }
                    .padding(.top, AppTheme.Spacing.md)
                }
            }
        }
        .task {
            await fetchStats()
        }
    }
    
    // MARK: - Fetch Stats
    private func fetchStats() async {
        isLoading = true
        do {
            let supabase = SupabaseManager.shared.client
            let session = try await supabase.auth.session
            
            let logs: [ConnectionLog] = try await supabase
                .from("connection_logs")
                .select()
                .eq("user_id", value: session.user.id.uuidString)
                .order("connected_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            let totalSessions = logs.count
            // Calculate duration from duration_seconds or estimate from timestamps
            let totalDuration = logs.reduce(0) { sum, log in
                if let dur = log.durationSeconds, dur > 0 {
                    return sum + dur
                }
                // Estimate: if we have connected_at and disconnected_at, compute diff
                if let connStr = log.connectedAt, let discStr = log.disconnectedAt,
                   let connDate = self.parseDate(connStr),
                   let discDate = self.parseDate(discStr) {
                    return sum + max(Int(discDate.timeIntervalSince(connDate)), 0)
                }
                return sum
            }
            let totalSent = logs.compactMap { $0.bytesSent }.reduce(0, +)
            let totalReceived = logs.compactMap { $0.bytesReceived }.reduce(0, +)
            
            // Calculate average speed: total bytes / total seconds (bytes/sec)
            let avgSpeed: Double = totalDuration > 0
                ? Double(totalSent + totalReceived) / Double(totalDuration)
                : 0
            
            usageStats = UsageStats(
                totalData: Int(totalSent + totalReceived),
                totalSessions: totalSessions,
                totalBytesSent: Int(totalSent),
                totalBytesReceived: Int(totalReceived),
                timeProtected: totalDuration,
                averageSpeed: avgSpeed,
                dailyData: []
            )
            
            let allServers = APIService.shared.cachedServers
            securityAudit = SecurityAudit(auditLog: logs.prefix(20).map { log in
                let server = allServers.first(where: { $0.id == log.serverId })
                return AuditLogEntry(
                    id: log.id ?? 0,
                    serverName: serverName(for: log.serverId),
                    serverCountry: server?.countryCode ?? "—",
                    connectedAt: log.connectedAt,
                    disconnectedAt: log.disconnectedAt,
                    duration: Double(log.durationSeconds ?? 0),
                    bytesSent: Int(log.bytesSent ?? 0),
                    bytesReceived: Int(log.bytesReceived ?? 0),
                    encrypted: true
                )
            })
        } catch {
            print("Failed to fetch stats: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    // MARK: - Formatting Helpers
    private func formatBytes(_ bytes: Int) -> String {
        let gb = Double(bytes) / 1_073_741_824
        let mb = Double(bytes) / 1_048_576
        if gb >= 1 {
            return String(format: "%.1f", gb)
        }
        return String(format: "%.1f", mb)
    }
    
    private func formatBytesUnit(_ bytes: Int) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return "GB" }
        return "MB"
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        let mbps = speed * 8 / 1_000_000
        return String(format: "%.0f", mbps)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 86400 {
            return "\(seconds / 86400)"
        } else if seconds >= 3600 {
            return String(format: "%.1f", Double(seconds) / 3600)
        }
        return "\(seconds / 60)"
    }
    
    private func formatDurationUnit(_ seconds: Int) -> String {
        if seconds >= 86400 { return "D" }
        if seconds >= 3600 { return "H" }
        return "M"
    }
    
    private func timeAgo(from dateString: String?) -> String {
        guard let dateString = dateString,
              let date = parseDate(dateString) else {
            return "—"
        }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
    
    /// Parse various date formats Supabase may return
    private func parseDate(_ string: String) -> Date? {
        // Try ISO8601 with fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        
        // Try without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }
        
        // Try Supabase default format: "2026-08-25 17:50:57.218+00"
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ"
        if let date = df.date(from: string) { return date }
        df.dateFormat = "yyyy-MM-dd HH:mm:ssZZZZZ"
        if let date = df.date(from: string) { return date }
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        if let date = df.date(from: string) { return date }
        
        return nil
    }
    
    /// Map server_id to a display name (uses dynamic server list from APIService)
    private func serverName(for serverId: Int) -> String {
        return APIService.shared.serverName(for: serverId)
    }
    
    // MARK: - Top Bar
    private var statsTopBar: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "shield")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("TECH VPN")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.5)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            Spacer()
            
            Circle()
                .fill(AppTheme.Colors.surfaceContainerHigh)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.secondary)
                )
        }
        .padding(.horizontal, AppTheme.Spacing.safeMargin)
        .frame(height: 64)
        .background(AppTheme.Colors.surface)
    }
    
    // MARK: - Section Header
    private var sectionHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NETWORK OVERVIEW")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(AppTheme.Colors.secondary)
                
                Text("Usage Analytics")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.onBackground)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 8, height: 8)
                
                Text("LIVE")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
    }
    
    // MARK: - Data Usage Card
    private var dataUsageCard: some View {
        // Show live session data if VPN is connected, otherwise show historical total
        let liveSessionBytes = Int(networkMonitor.sessionBytesDown + networkMonitor.sessionBytesUp)
        let historicalBytes = usageStats?.totalData ?? 0
        let displayBytes = vpnManager.isConnected ? liveSessionBytes + historicalBytes : historicalBytes
        
        return VStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "#161616"), lineWidth: 8)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .trim(from: 0, to: displayBytes > 0 ? 1.0 : 0.0)
                    .stroke(AppTheme.Colors.primaryContainer, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text(formatBytes(displayBytes))
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundColor(AppTheme.Colors.onBackground)
                    
                    Text("\(formatBytesUnit(displayBytes)) USED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(AppTheme.Colors.secondary)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.secondary.opacity(0.6))
                    Text("\(formatBytes(Int(networkMonitor.sessionBytesDown) + (usageStats?.totalBytesReceived ?? 0))) \(formatBytesUnit(Int(networkMonitor.sessionBytesDown) + (usageStats?.totalBytesReceived ?? 0)))")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.onSurface)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Upload")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.secondary.opacity(0.6))
                    Text("\(formatBytes(Int(networkMonitor.sessionBytesUp) + (usageStats?.totalBytesSent ?? 0))) \(formatBytesUnit(Int(networkMonitor.sessionBytesUp) + (usageStats?.totalBytesSent ?? 0)))")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(hex: "#161616"))
        .cornerRadius(AppTheme.Radius.xl)
        .overlay(
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, AppTheme.Colors.primaryContainer.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                Spacer()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
    }
    
    // MARK: - Speed Trends Card
    private var speedTrendsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("SPEED TRENDS (MBPS)")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(AppTheme.Colors.secondary)
                
                Spacer()
                
                Image(systemName: "ellipsis")
                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.4))
            }
            
            // Live speed chart from NetworkMonitor
            SpeedChartView(samples: networkMonitor.speedHistory)
                .frame(height: 120)
        }
        .padding(AppTheme.Spacing.md)
        .background(Color(hex: "#161616"))
        .cornerRadius(AppTheme.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Stats Grid
    private var statsGrid: some View {
        let stats = usageStats
        let historicalData = stats?.totalData ?? 0
        let liveSessionData = Int(networkMonitor.sessionBytesDown + networkMonitor.sessionBytesUp)
        let totalData = historicalData + liveSessionData
        let sessions = stats?.totalSessions ?? 0
        
        // AVG Speed: use live session average if connected, otherwise historical
        let liveAvg = networkMonitor.sessionAverageSpeed
        let historicalAvg = stats?.averageSpeed ?? 0
        let avgSpeedMbps = liveAvg > 0 ? liveAvg : (historicalAvg * 8.0 / 1_000_000.0)
        
        // Protected time: historical + current session duration
        let historicalTime = stats?.timeProtected ?? 0
        let liveTime = Int(networkMonitor.sessionDuration)
        let timeProtected = historicalTime + liveTime
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.gutter) {
            StatGridItem(icon: "externaldrive.fill", label: "TOTAL DATA", value: formatBytes(totalData), unit: formatBytesUnit(totalData))
            StatGridItem(icon: "clock.arrow.circlepath", label: "SESSIONS", value: "\(sessions)", unit: "")
            StatGridItem(icon: "speedometer", label: "AVG SPEED", value: String(format: "%.1f", avgSpeedMbps), unit: "MBPS")
            StatGridItem(icon: "checkmark.shield.fill", label: "PROTECTED", value: formatDuration(timeProtected), unit: formatDurationUnit(timeProtected))
        }
    }
    
    // MARK: - Security Audit
    private var securityAuditCard: some View {
        let logEntries = securityAudit?.auditLog ?? []
        let hasRealData = !logEntries.isEmpty
        
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("SECURITY AUDIT")
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundColor(AppTheme.Colors.secondary)
            
            if hasRealData {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(Array(logEntries.prefix(5)), id: \.id) { entry in
                        AuditRow(
                            icon: entry.encrypted ? "lock.fill" : "globe",
                            iconBgColor: entry.encrypted ? AppTheme.Colors.secondary.opacity(0.1) : AppTheme.Colors.primary.opacity(0.1),
                            iconColor: entry.encrypted ? AppTheme.Colors.secondary : AppTheme.Colors.primary,
                            title: entry.serverName ?? entry.serverCountry ?? "Server",
                            subtitle: entry.encrypted ? "AES-256 Encrypted" : "Connection established",
                            time: timeAgo(from: entry.connectedAt),
                            opacity: 1.0
                        )
                    }
                }
            } else {
                Text("No connection history yet")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppTheme.Spacing.lg)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(Color(hex: "#161616"))
        .cornerRadius(AppTheme.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Speed Chart View
struct SpeedChartView: View {
    var samples: [NetworkMonitor.SpeedSample] = []
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Grid lines
            ForEach(0..<5) { i in
                let y = height * CGFloat(i) / 4.0
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
            
            if samples.count >= 2 {
                let maxSpeed = max(samples.map { max($0.download, $0.upload) }.max() ?? 1.0, 0.1)
                
                // Download line (primary color)
                Path { path in
                    for (index, sample) in samples.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(samples.count - 1)
                        let y = height - (height * CGFloat(sample.download / maxSpeed))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    AppTheme.Colors.primaryContainer,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: AppTheme.Colors.primaryContainer.opacity(0.3), radius: 4, y: 2)
                
                // Upload line (secondary/dimmer color)
                Path { path in
                    for (index, sample) in samples.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(samples.count - 1)
                        let y = height - (height * CGFloat(sample.upload / maxSpeed))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    AppTheme.Colors.primary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            } else {
                // No data placeholder text
                Text("Waiting for data...")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.secondary.opacity(0.4))
                    .position(x: width / 2, y: height / 2)
            }
        }
    }
}

// MARK: - Stat Grid Item
struct StatGridItem: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.onSurface)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(Color(hex: "#161616"))
        .cornerRadius(AppTheme.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Audit Row
struct AuditRow: View {
    let icon: String
    let iconBgColor: Color
    let iconColor: Color
    let title: String
    let subtitle: String
    let time: String
    let opacity: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(iconBgColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.onSurface)
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            
            Spacer()
            
            Text(time)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(AppTheme.Colors.secondary)
        }
        .opacity(opacity)
    }
}

#Preview {
    StatsView(vpnManager: VPNManager())
}
