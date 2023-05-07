//
//  RecordUtil.swift
//  MacOSApp
//
//  Created by Tuan Hoang on 07/05/2023.
//

import Foundation

final class RecordUtil {
    static func urlForRecordFolder() -> URL? {
        let fileManager = FileManager.default
        guard let cacheUrl = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let recordFolderUrl = cacheUrl.appendingPathComponent("MACOSAPP").appendingPathComponent(RecordConstants.recordFolderName)
        var isDirectory: ObjCBool = false
        let isFolderExists = fileManager.fileExists(atPath: recordFolderUrl.path, isDirectory: &isDirectory)

        if !isFolderExists || !isDirectory.boolValue {
            do {
                try fileManager.createDirectory(at: recordFolderUrl,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
            } catch {
                return nil
            }
        }

        return recordFolderUrl
    }

    static func generateRecordFileURL() -> URL? {
        guard let recordFolderURL = urlForRecordFolder() else {
            return nil
        }

        let dataFileUrl = recordFolderURL.appendingPathComponent("RecordDemo.m4a")
        return dataFileUrl
    }
}
