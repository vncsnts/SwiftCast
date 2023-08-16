//
//  APIRequestService.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/16/23.
//

import Foundation

actor APIRequestService {
    public static let shared = APIRequestService()
    
    lazy var domainUrl: URL = {
        guard let url = URL(string: "") else {
            fatalError("Invalid URL: ''")
        }
        return url
    }()
    
    lazy var finalizeUrl: URL = {
        guard let url = URL(string: "") else {
            fatalError("Invalid URL: ''")
        }
        return url
    }()
    
    public var accessToken: String? {
        get {
            return UserDefaults.standard.string(forKey: "accessToken") ?? ""
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "accessToken")
        }
    }
            
    func setAccessToken(token: String) {
        accessToken = token
    }
}

extension APIRequestService {
    func initializeService() async throws {
    }
    
    /// Send Recording Chunks  to SwiftCast Server
    /// - Parameter id: unique recording ID, probably a UUID
    func sendChunk(chunkFileName: String, chunk: Data) async throws -> String {
        return ""
    }
    
    func finalizeRecordings(chunkUrls: [String]) async throws -> String {
        return ""
    }
}
