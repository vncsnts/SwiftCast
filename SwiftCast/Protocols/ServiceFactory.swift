//
//  ServiceFactory.swift
//  SwiftCast
//

import Foundation

/// Central dependency locator for the app's services. Built once and injected into
/// ViewModels via init (with the shared default), so no ViewModel or View reaches for
/// a concrete `.shared` singleton directly and any service can be swapped for a test
/// double at a single boundary.
protocol ServiceFactory {
    var apiRequestService: any APIRequestService { get }
    var apiQueueService: any APIQueueService { get }
    var faceTrackingService: any FaceTrackingService { get }
    var videoExportService: any VideoExportService { get }
    var fileManager: any SwiftCastFileManager { get }
}
