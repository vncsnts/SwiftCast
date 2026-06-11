//
//  APIRequestService.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/12/26.
//

import Foundation

/// Sends recording data to the SwiftCast server.
protocol APIRequestService {
    /// The access token used to authenticate requests.
    var accessToken: String? { get async }

    /// Stores the access token for subsequent requests.
    func setAccessToken(token: String) async

    /// Prepares the service before the first request.
    func initializeService() async throws

    /// Sends a recording chunk to the server and returns its public URL.
    func sendChunk(chunkFileName: String, chunk: Data) async throws -> String

    /// Finalizes a recording from its uploaded chunk URLs and returns the result.
    func finalizeRecordings(chunkUrls: [String]) async throws -> String
}
