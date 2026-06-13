//
//  LibraryViewModel.swift
//  SwiftCast
//

import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var sessions: [RecordingSession] = []
    @Published var isLoading = false
    @Published var alertMessage = ""
    @Published var isOnAlert = false

    func loadSessions() {
        isLoading = true
        Task {
            sessions = await fetchSessions()
            isLoading = false
        }
    }

    func deleteSession(_ session: RecordingSession) {
        do {
            try FileManager.default.removeItem(at: session.folderURL)
            sessions.removeAll { $0.id == session.id }
        } catch {
            alertMessage = error.localizedDescription
            isOnAlert = true
        }
    }

    private func fetchSessions() async -> [RecordingSession] {
        guard let moviesURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first else { return [] }
        let baseURL = moviesURL.appendingPathComponent("SwiftCast")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        var result: [RecordingSession] = []
        for url in contents {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let sessionId = url.lastPathComponent
            let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
            let date = RecordingSession.date(from: sessionId) ?? creationDate

            let screenURL = url.appendingPathComponent("screenClip.mp4")
            let cameraURL = url.appendingPathComponent("cameraClip.mp4")
            let exportedURL = url.appendingPathComponent("exported.mp4")

            var session = RecordingSession(id: sessionId, date: date, folderURL: url)
            session.screenClipURL = FileManager.default.fileExists(atPath: screenURL.path) ? screenURL : nil
            session.cameraClipURL = FileManager.default.fileExists(atPath: cameraURL.path) ? cameraURL : nil
            session.exportedVideoURL = FileManager.default.fileExists(atPath: exportedURL.path) ? exportedURL : nil

            result.append(session)
        }

        return result.sorted { $0.date > $1.date }
    }
}
