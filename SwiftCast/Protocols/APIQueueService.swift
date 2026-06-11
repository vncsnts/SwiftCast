//
//  APIQueueService.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/12/26.
//

import Foundation

/// Queues recording chunks stored on disk and uploads them when a
/// connection is available.
protocol APIQueueService {
    /// The public URLs of the screen chunks uploaded so far.
    func getScreenChunkUrls() async -> [String]

    /// The public URLs of the camera chunks uploaded so far.
    func getCameraChunkUrls() async -> [String]

    /// Clears the tracked screen and camera chunk URLs.
    func removeAllUrls() async

    /// Deletes all queued chunk files from disk.
    func deleteAllChunks() async

    /// Starts the screen queue checker, uploading queued chunks periodically.
    func startScreenQueueChecker() async

    /// Stops the screen queue checker.
    func stopScreenQueueChecker() async

    /// Starts the camera queue checker, uploading queued chunks periodically.
    func startCameraQueueChecker() async

    /// Stops the camera queue checker.
    func stopCameraQueueChecker() async
}
