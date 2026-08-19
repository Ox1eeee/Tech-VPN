//
//  SupabaseManager.swift
//  Tech VPN
//
//  Created by Xylo on 11/08/26.
//

import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://lcrdfeqhdjauivfdpkdm.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjcmRmZXFoZGphdWl2ZmRwa2RtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYzODkzMDgsImV4cCI6MjEwMTk2NTMwOH0.JpDIdTKnQJPt2zOVKN49LxtfBCf5Q_g5RRNaBHfgEmw"
        )
    }
}
