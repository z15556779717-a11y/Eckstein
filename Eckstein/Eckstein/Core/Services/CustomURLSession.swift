//
//  CustomURLSession.swift
//  Eckstein
//
//  Created by Assistant on 15/07/2025.
//

import Foundation

class CustomURLSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.default
        
        // Aggressive timeout and retry settings
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        
        // Disable caching to avoid stale responses
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        
        // Custom protocol classes to handle the connection issues
        configuration.protocolClasses = [CustomHTTPProtocol.self]
        
        return URLSession(configuration: configuration)
    }()
}

// Custom protocol to intercept and fix the connection issues
class CustomHTTPProtocol: URLProtocol {
    private var sessionTask: URLSessionDataTask?
    
    override class func canInit(with request: URLRequest) -> Bool {
        // Only handle Supabase requests
        guard let url = request.url,
              let host = url.host,
              host.contains("supabase.co") else {
            return false
        }
        
        // Check if we've already processed this request
        if URLProtocol.property(forKey: "CustomHTTPProtocolHandled", in: request) != nil {
            return false
        }
        
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        
        // Mark this request as handled
        URLProtocol.setProperty(true, forKey: "CustomHTTPProtocolHandled", in: mutableRequest)
        
        // Add custom headers that might help
        mutableRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        mutableRequest.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        // Create a new session for this request
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.waitsForConnectivity = true
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        sessionTask = session.dataTask(with: mutableRequest as URLRequest)
        sessionTask?.resume()
    }
    
    override func stopLoading() {
        sessionTask?.cancel()
        sessionTask = nil
    }
}

extension CustomHTTPProtocol: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}