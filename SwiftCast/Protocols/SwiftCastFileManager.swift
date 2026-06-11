//
//  SwiftCastFileManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/12/26.
//

import Foundation

/// Stores and retrieves SwiftCast files in the app's folders on disk.
protocol SwiftCastFileManager {
    /// Creates the necessary folders for SwiftCast.
    func createAppFolders()

    /// Adds a file with the given name, type, and contents to a folder.
    func add(fileName: String, fileType: SwiftCastFileManagerFileType, value: Data, folder: SwiftCastFileManagerFolder) async -> Result<Void, StringError>

    /// Gets the contents of a file from a folder, if it exists.
    func get(fileName: String, fileType: SwiftCastFileManagerFileType, folder: SwiftCastFileManagerFolder) async -> Data?

    /// Removes the file at the given URL. Returns whether removal succeeded.
    func remove(url: URL) async -> Bool

    /// Gets the contents of the file at the given URL, if it exists.
    func getFromUrl(url: URL) async -> Data?

    /// Gets all files in a folder, sorted by creation date ascending.
    func getFolderFiles(folder: SwiftCastFileManagerFolder) async -> [URL]?
}
