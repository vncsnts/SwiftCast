//
//  RecordingSession.swift
//  SwiftCast
//

import Foundation

struct RecordingSession: Identifiable, Hashable {
    let id: String
    let date: Date
    let folderURL: URL
    var screenClipURL: URL?
    var cameraClipURL: URL?
    var exportedVideoURL: URL?

    var displayTitle: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    static func makeSessionId(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f.string(from: date)
    }

    static func date(from sessionId: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f.date(from: sessionId)
    }
}
