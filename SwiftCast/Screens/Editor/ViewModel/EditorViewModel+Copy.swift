//
//  EditorViewModel+Copy.swift
//  SwiftCast
//

import Foundation

extension EditorViewModel {
    enum Copy {
        static let title = "Editor"
        static let exportButton = "Export"
        static let exportingLabel = "Exporting…"
        static let exportDoneTitle = "Export Complete"
        static let exportDoneMessage = "Your video has been saved to the session folder."
        static let exportErrorTitle = "Export Failed"
        static let resetButton = "Reset Layout"
        static let maskSectionTitle = "Mask"
        static let focusSectionTitle = "Focus"
        static let zoomLabel = "Zoom"
        static let faceTrackingLabel = "Face Tracking"
        static let faceTrackingNoFaceMessage = "No face was detected in the camera clip."
        static let manualFocusHint = "Hold the camera clip to adjust focus"
        static let alertTitle = "SwiftCast"
    }
}
