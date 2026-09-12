//
//  NetworkDiagnosticsView.swift
//  Eckstein
//
//  Created by Assistant on 15/07/2025.
//

import SwiftUI
import Network

struct NetworkDiagnosticsView: View {
    @State private var diagnosticResults = ""
    @State private var isRunning = false
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Network Status
                    GroupBox("Current Network Status") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Connected:")
                                Text(networkMonitor.isConnected ? "Yes" : "No")
                                    .foregroundColor(networkMonitor.isConnected ? .green : .red)
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Connection Type:")
                                Text("\(networkMonitor.connectionType)")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Expensive:")
                                Text(networkMonitor.isExpensive ? "Yes" : "No")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button("Run Network Diagnostics") {
                        runDiagnostics()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                    
                    if isRunning {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Results
                    if !diagnosticResults.isEmpty {
                        GroupBox("Diagnostic Results") {
                            ScrollView {
                                Text(diagnosticResults)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .frame(height: 400)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Network Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func runDiagnostics() {
        isRunning = true
        diagnosticResults = "Starting network diagnostics...\n\n"
        
        Task {
            // Test 1: Basic reachability
            diagnosticResults += "=== Basic Reachability Test ===\n"
            await testBasicReachability()
            
            // Test 2: DNS Resolution
            diagnosticResults += "\n=== DNS Resolution Test ===\n"
            await testDNSResolution()
            
            // Test 3: HTTPS Request
            diagnosticResults += "\n=== HTTPS Request Test ===\n"
            await testHTTPSRequest()
            
            // Test 4: Supabase Specific
            diagnosticResults += "\n=== Supabase Connection Test ===\n"
            await testSupabaseConnection()
            
            // Test 5: URLSession Configuration
            diagnosticResults += "\n=== URLSession Configuration ===\n"
            checkURLSessionConfig()
            
            isRunning = false
        }
    }
    
    private func testBasicReachability() async {
        // Test common endpoints
        let endpoints = [
            "https://www.google.com",
            "https://api.github.com",
            "https://www.cloudflare.com"
        ]
        
        for endpoint in endpoints {
            if let url = URL(string: endpoint) {
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 5.0
                    
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse {
                        diagnosticResults += "✅ \(endpoint): Status \(httpResponse.statusCode)\n"
                    }
                } catch {
                    diagnosticResults += "❌ \(endpoint): \(error.localizedDescription)\n"
                }
            }
        }
    }
    
    private func testDNSResolution() async {
        // The host the app is actually configured with, not a fixed one:
        // a diagnostic that resolves the wrong project reports success for a
        // project this build cannot reach.
        let host = AppEnvironment.supabaseURL.host ?? "unconfigured.invalid"
        diagnosticResults += "Resolving \(host)...\n"
        
        let hostRef = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
        var resolved: DarwinBoolean = false
        
        CFHostStartInfoResolution(hostRef, .addresses, nil)
        
        if let addresses = CFHostGetAddressing(hostRef, &resolved)?.takeUnretainedValue() as? [Data], resolved.boolValue {
            for address in addresses {
                diagnosticResults += "✅ Resolved to: \(address.map { String($0) }.joined(separator: "."))\n"
            }
        } else {
            diagnosticResults += "❌ Failed to resolve DNS\n"
        }
    }
    
    private func testHTTPSRequest() async {
        do {
            let url = URL(string: "https://httpbin.org/get")!
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                diagnosticResults += "✅ HTTPS test: Status \(httpResponse.statusCode)\n"
                if let responseString = String(data: data, encoding: .utf8) {
                    diagnosticResults += "Response preview: \(String(responseString.prefix(100)))...\n"
                }
            }
        } catch {
            diagnosticResults += "❌ HTTPS test failed: \(error)\n"
        }
    }
    
    private func testSupabaseConnection() async {
        let baseURL = AppEnvironment.supabaseURL.absoluteString
        diagnosticResults += "Testing Supabase at: \(baseURL)\n"
        
        // Test 1: Basic connection
        do {
            let healthURL = URL(string: "\(baseURL)/rest/v1/")!
            var request = URLRequest(url: healthURL)
            request.httpMethod = "GET"
            request.setValue(AppEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.timeoutInterval = 10.0
            
            diagnosticResults += "Sending request to: \(healthURL)\n"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                diagnosticResults += "✅ Supabase response: Status \(httpResponse.statusCode)\n"
                diagnosticResults += "Headers: \(httpResponse.allHeaderFields)\n"
                
                if let responseString = String(data: data, encoding: .utf8) {
                    diagnosticResults += "Body: \(responseString)\n"
                }
            }
        } catch let error as NSError {
            diagnosticResults += "❌ Supabase error: \(error)\n"
            diagnosticResults += "Error code: \(error.code)\n"
            diagnosticResults += "Error domain: \(error.domain)\n"
            diagnosticResults += "User info: \(error.userInfo)\n"
        }
    }
    
    private func checkURLSessionConfig() {
        let config = URLSessionConfiguration.default
        diagnosticResults += "Allow cellular: \(config.allowsCellularAccess)\n"
        diagnosticResults += "Timeout interval: \(config.timeoutIntervalForRequest)s\n"
        diagnosticResults += "Timeout for resource: \(config.timeoutIntervalForResource)s\n"
        diagnosticResults += "Allows expensive: \(config.allowsExpensiveNetworkAccess)\n"
        diagnosticResults += "Allows constrained: \(config.allowsConstrainedNetworkAccess)\n"
        
        // Check ATS
        if let atsSettings = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any] {
            diagnosticResults += "\nATS Settings: \(atsSettings)\n"
        } else {
            diagnosticResults += "\nNo custom ATS settings found\n"
        }
    }
}

#Preview {
    NetworkDiagnosticsView()
}