//
//  APIQueueService.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/16/23.
//

import Foundation

/// Service for the API Queuer that stores payload locally on the .apiQueue Folder from SwiftCastFileManager
actor APIQueueService {
    static let shared = APIQueueService()
    public var urlErrorsForQueue = [URLError.Code.networkConnectionLost, URLError.Code.notConnectedToInternet, URLError.Code.dataNotAllowed]
    private var isScreenQueueBusy = false
    private var isCheckingScreenQueue = true
    private var isCameraQueueBusy = false
    private var isCheckingCameraQueue = true
    private var nanosecondToSecondMultiplier = 1000000000
    private var screenChunkUrls = [String]()
    private var cameraChunkUrls = [String]()
    
    /// Converts seconds to nanaoseconds for Tasks
    /// - Parameter seconds: the seconds value
    /// - Returns: returns the nanosecond value
    private func convertSecondToNanoSecond(seconds: Int) -> UInt64 {
        return UInt64(seconds * nanosecondToSecondMultiplier)
    }
    
    func getScreenChunkUrls() -> [String] {
         return screenChunkUrls
    }
    
    func getCameraChunkUrls() -> [String] {
         return cameraChunkUrls
    }
    
    func removeAllUrls() {
        screenChunkUrls.removeAll()
        cameraChunkUrls.removeAll()
    }
    
    func deleteAllChunks() async {
        Task {
            guard let currentScreenOnStorage = await SwiftCastFileManager.shared.getFolderFiles(folder: .screenQueue) else { return }
            for url in currentScreenOnStorage {
                let _ = await SwiftCastFileManager.shared.remove(url: url)
            }
            guard let currentCameraOnStorage = await SwiftCastFileManager.shared.getFolderFiles(folder: .cameraQueue) else { return }
            for url in currentCameraOnStorage {
                let _ = await SwiftCastFileManager.shared.remove(url: url)
            }
        }
    }
    
    /// Starts the APIQueue checker and checks the queue every minute, does not execute when APIQueueService isBusy
    func startScreenQueueChecker() async {
        screenChunkUrls.removeAll()
        repeat {
            try? await Task.sleep(nanoseconds: convertSecondToNanoSecond(seconds: 5))
            if !isScreenQueueBusy && InternetConnection.check() {
                await processTheFirstScreenBitOnStorage()
            }
        } while isCheckingScreenQueue
    }
    
    func stopScreenQueueChecker() {
        isCheckingScreenQueue = false
    }
    
    func startCameraQueueChecker() async {
        cameraChunkUrls.removeAll()
        repeat {
            try? await Task.sleep(nanoseconds: convertSecondToNanoSecond(seconds: 5))
            if !isCameraQueueBusy && InternetConnection.check() {
                await processTheFirstCameraBitOnStorage()
            }
        } while isCheckingCameraQueue
    }
    
    func stopCameraQueueChecker() {
        isCheckingCameraQueue = false
    }
    
    /// Converts the payload to data to be stored on SwiftCastFileManager
    /// - Parameter payload: the payload to save
    /// - Returns: returns the data if success else retuns an error
    private func convertPayloadToData(payload: [[String : Any]]) async -> Result<Data, Error> {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            return .success(data)
        } catch {
            return .failure(error)
        }
    }
    
    /// Converts a given Data to payload
    /// - Parameter data: the data to convert
    /// - Returns: returns the payload if data conversion suceeds else returns the error
    private func convertDataToPayload(data: Data) async -> Result<[[String : Any]], Error> {
        do {
            let decodedDictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [[String: Any]]
            return .success(decodedDictionary)
        } catch {
            return .failure(error)
        }
    }
    
    /// Processes the first file seen when APIQueueService is not busy
    private func processTheFirstScreenBitOnStorage() async {
        isScreenQueueBusy = true
        guard let currentQueueOnStorage = await SwiftCastFileManager.shared.getFolderFiles(folder: .screenQueue) else { return }
        for url in currentQueueOnStorage {
            guard let data = await SwiftCastFileManager.shared.getFromUrl(url: url) else { return }
            let fullFileName = url.lastPathComponent
            
            guard let _ = try? await APIRequestService.shared.sendChunk(chunkFileName: fullFileName, chunk: data) else { break }
            let _ = await SwiftCastFileManager.shared.remove(url: url)
            screenChunkUrls.append(fullFileName)
        }
        isScreenQueueBusy = false
    }
    
    private func processTheFirstCameraBitOnStorage() async {
        isCameraQueueBusy = true
        guard let currentQueueOnStorage = await SwiftCastFileManager.shared.getFolderFiles(folder: .cameraQueue) else { return }
        for url in currentQueueOnStorage {
            guard let data = await SwiftCastFileManager.shared.getFromUrl(url: url) else { return }
            let fullFileName = url.lastPathComponent
            
            guard let _ = try? await APIRequestService.shared.sendChunk(chunkFileName: fullFileName, chunk: data) else { break }
            let _ = await SwiftCastFileManager.shared.remove(url: url)
            cameraChunkUrls.append(fullFileName)
        }
        isCameraQueueBusy = false
    }
}
