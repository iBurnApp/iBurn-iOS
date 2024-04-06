//
//  BRCDataImporter.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import MapLibre
import CocoaLumberjack
import Zip

extension BRCDataImporter {
    /** Downloads offline tiles from iBurn server */
    public static func downloadOfflineTiles() {
        // TODO: download our own offline tiles
        
    }
    
    @objc public static func copyDatabaseFromBundle() -> Bool {
        guard let zipURL = Bundle.main.url(forResource: kBRCDatabaseFolderName, withExtension: "zip") else {
            print("No bundled database found!")
            return false
        }
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            print("No bundled database found at: \(zipURL.path)")
            return false
        }
        let databaseDirectory = BRCDatabaseManager.yapDatabaseDirectory
        let databaseDirectoryURL = URL(fileURLWithPath: databaseDirectory)
        let containingDirectory = databaseDirectoryURL.deletingLastPathComponent()
        
        do {
            if !FileManager.default.fileExists(atPath: containingDirectory.path) {
                try FileManager.default.createDirectory(at: containingDirectory, withIntermediateDirectories: true)
            }
            
            let unzipDirectory = try Zip.quickUnzipFile(zipURL)
            defer {
                try? FileManager.default.removeItem(at: unzipDirectory)
            }
            let innerFolder = unzipDirectory.appendingPathComponent(kBRCDatabaseFolderName)
            print("Unzipped bundled database to: \(unzipDirectory)")
            try FileManager.default.moveItem(at: innerFolder, to: databaseDirectoryURL)
            print("Bundled database imported to: \(databaseDirectoryURL)")
        } catch {
            print("Error copying bundled database: \(error)")
            return false
        }
        return true
    }

}
