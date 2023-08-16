//
//  SwiftCastFileManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/16/23.
//

import Foundation

actor SwiftCastFileManager {
    static let shared = SwiftCastFileManager()
    
    /// Creates the necessary Folders for SwiftCast
    nonisolated func createAppFolders() {
        for folder in SwiftCastFileManagerFolder.allCases {
            createFoldersIfNeeded(folder: folder.rawValue)
        }
    }
    
    /// Create a folder if needed
    /// - Parameter folder: the name of the folder
    nonisolated private func createFoldersIfNeeded(folder: String) {
        guard let url = getFolderPath(for: folder) else { return }
        
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                print("Created a folder named \(folder) from SwiftCastFileManager!")
            } catch {
                print("Error on creating a folder named \(folder)")
            }
        }
    }
    
    /// Get a folder based on the given folderName
    /// - Parameter folderName: the folder name to find
    /// - Returns: the url for the path
    nonisolated private func getFolderPath(for folderName: String) -> URL? {
        return FileManager
            .default
            .urls(for: .moviesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(folderName)
    }
    
    /// Gets the Data Path for a Given Data
    /// - Parameters:
    ///   - fileName: the filename for the data
    ///   - fileType: the filetype for the data
    ///   - fromFolder: the folder to store the file
    /// - Returns: Returns the URL for the Data
    private func getDataPath(fileName: String, fileType: SwiftCastFileManagerFileType, fromFolder: SwiftCastFileManagerFolder) -> URL? {
        guard let folder = getFolderPath(for: fromFolder.rawValue) else { return nil }
        return folder.appendingPathComponent(fileName + fileType.rawValue)
    }
    
    /// Add a File to SwiftCast File Manager
    /// - Parameters:
    ///   - fileName: the given  file name
    ///   - fileType: the given file type
    ///   - value: the data value
    ///   - folder: the folder to store the file
    func add(fileName: String, fileType: SwiftCastFileManagerFileType, value: Data, folder: SwiftCastFileManagerFolder) -> Result<Void, StringError> {
        guard let url = getDataPath(fileName: fileName, fileType: fileType, fromFolder: folder) else { return .failure(.init(message: "Failed to Generate Data Path of \(fileName)\(fileType)")) }
        do {
            try value.write(to: url)
            return .success(())
        } catch {
            let errorMessage = "Error adding file \(fileName)\(fileName) to folder \(folder)\nWith Error Description: \(error.localizedDescription)"
            return .failure(.init(message: errorMessage))
        }
    }
    
    /// Gets a Data from SwiftCast File Manager
    /// - Parameters:
    ///   - fileName: the filename
    ///   - fileType: the filetype
    ///   - folder: the folder to get it from
    /// - Returns: An Optional Data
    func get(fileName: String, fileType: SwiftCastFileManagerFileType, folder: SwiftCastFileManagerFolder) -> Data? {
        guard let url = getDataPath(fileName: fileName, fileType: fileType, fromFolder: folder), FileManager.default.fileExists(atPath: url.pathExtension) else { return nil}
        do {
            return try Data(contentsOf: url)
        } catch {
            return nil
        }
    }
    
    /// Removes a file based from the url given
    /// - Parameter url: the URL of the file
    /// - Returns: Returns the error with NSError and String Description
    func remove(url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }
    
    /// Gets a file from the given URL
    /// - Parameter url: the URL of file
    /// - Returns: returns the Data from the URL
    func getFromUrl(url: URL) -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch {
            return nil
        }
    }
    
    /// Gets all the files from a given folder
    /// - Parameter folder: the Folder to check
    /// - Returns: the Array of URL's from the Folder
    func getFolderFiles(folder: SwiftCastFileManagerFolder) -> [URL]? {
        do {
            guard let queueFolderPath = getFolderPath(for: folder.rawValue) else { return nil }
            let fileURLs = try FileManager.default.contentsOfDirectory(at: queueFolderPath, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            let sortedURLs = fileURLs.sorted {
                guard let date1 = try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate,
                    let date2 = try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                        return false
                }
                
                return date1.compare(date2) == .orderedAscending
            }
            
            return sortedURLs
        } catch {
            print("Error while enumerating files: \(error.localizedDescription)")
            return nil
        }
    }
}

/// An enum for all possible folders for SwiftCast
enum SwiftCastFileManagerFolder: String, CaseIterable {
    case screenQueue = "SwiftCast-Screen-Segments"
    case cameraQueue = "SwiftCast-Camera-Segments"
}

/// An enum for all possible custom file types for SwiftCast
enum SwiftCastFileManagerFileType: String {
    case apiQueue = ".mp4"
}

/// An Error with an option to add a custom message and supply the data that caused the error as optional
struct StringError: Error {
    var message: String
    var nsError: NSError?
}
