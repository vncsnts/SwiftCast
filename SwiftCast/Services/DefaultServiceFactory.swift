//
//  DefaultServiceFactory.swift
//  SwiftCast
//

import Foundation

final class DefaultServiceFactory: ServiceFactory {
    static let shared = DefaultServiceFactory()

    private init() {}

    // Computed accessors keep initialisation lazy: each underlying service is only
    // instantiated the first time something asks for it.
    var apiRequestService: any APIRequestService { DefaultAPIRequestService.shared }
    var apiQueueService: any APIQueueService { DefaultAPIQueueService.shared }
    var faceTrackingService: any FaceTrackingService { DefaultFaceTrackingService.shared }
    var videoExportService: any VideoExportService { DefaultVideoExportService.shared }
    var fileManager: any SwiftCastFileManager { DefaultSwiftCastFileManager.shared }
}
