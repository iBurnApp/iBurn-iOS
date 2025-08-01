//
//  BRCMediaDownloader.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/8/16.
//  Copyright 2016 Burning Man Earth. All rights reserved.

import Foundation
import YapDatabase
import CocoaLumberjack


@objc
public enum BRCMediaDownloadType: Int
{
    case unknown = 0
    case audio
    case image
}

extension Bundle {
    
    /** Media files bundled w/ the app */
    static var bundledMedia: Bundle? {
        return Bundle.brc_mediaBundle
    }
}

public final class BRCMediaDownloader: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    
    static let mediaFolderName = "MediaFiles"

    let viewName: String
    let connection: YapDatabaseConnection
    var session: Foundation.URLSession!
    
    let downloadType: BRCMediaDownloadType
    @objc public let backgroundSessionIdentifier: String
    var observer: NSObjectProtocol?
    @objc public var backgroundCompletion: (()->())?
    let delegateQueue = OperationQueue()
    private let backgroundTaskQueue = DispatchQueue(label: "backgroundTaskQueue")
    /// isolate access on `backgroundTaskQueue`
    private var backgroundTasks: [Int: UIBackgroundTaskIdentifier] = [:]
    
    // Clean typealiases for all protocol compositions
    typealias DataObjectWithMetadata = BRCDataObject & BRCMetadataProtocol
    typealias ThumbnailDataObject = BRCDataObject & BRCThumbnailProtocol & BRCMetadataProtocol  
    typealias ProcessableObject = BRCDataObject & BRCThumbnailProtocol
    typealias ColorableMetadata = BRCObjectMetadata & BRCThumbnailImageColorsProtocol
    
    /** Collections to process for object operations */
    private let collections = [BRCArtObject.yapCollection, BRCCampObject.yapCollection]
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    @objc public init(connection: YapDatabaseConnection, viewName: String, downloadType: BRCMediaDownloadType) {
        self.downloadType = downloadType
        self.connection = connection
        self.viewName = viewName
        let backgroundSessionIdentifier = "BRCMediaDownloaderSession" + viewName
        self.backgroundSessionIdentifier = backgroundSessionIdentifier
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        super.init()
        self.session = Foundation.URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.BRCDatabaseExtensionRegistered, object: BRCDatabaseManager.shared, queue: OperationQueue.main) { (notification) in
            if let extensionName = notification.userInfo?["extensionName"] as? String {
                if extensionName == self.viewName {
                    NSLog("BRCMediaDownloader databaseExtensionRegistered: %@", extensionName)
                    self.downloadUncachedMedia()
                }
            }
        }
    }
    
    private static var mediaFilesPath: String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let folderName = BRCMediaDownloader.mediaFolderName
        let path = documentsPath.appendingPathComponent(folderName)
        return path
    }
    
    
    /** Copies media files like images/mp3s that were bundled with the app */
    private static func copyMediaFilesIfNeeded() {
        guard let bundle = Bundle.bundledMedia, let bundlePath = bundle.resourcePath else {
            return
        }
        let path = BRCMediaDownloader.mediaFilesPath
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.copyItem(atPath: bundlePath, toPath: path)
                var fileURL = URL(fileURLWithPath: path)
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try fileURL.setResourceValues(resourceValues)
            } catch let error {
                DDLogError("Error copying media files \(error)")
            }
        }
    }
    
    /** This is where a local file WOULD be located, but the file may not be there */
    public static func localCacheURL(_ fileName: String) -> URL {
        let localCache = BRCMediaDownloader.mediaFilesPath
        let localURL = URL(fileURLWithPath: localCache)
        let fileURL = localURL.appendingPathComponent(fileName)
        return fileURL
    }
    
    /** Checks if file exists first, Prefer downloaded media over bundled */
    @objc public static func localMediaURL(_ fileName: String) -> URL? {
        copyMediaFilesIfNeeded()
        let fileURL = self.localCacheURL(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        let bundle = Bundle.bundledMedia
        let url = bundle?.url(forResource: fileName, withExtension: nil)
        return url
    }
    
    public static func imageForArt(_ art: BRCArtObject) -> UIImage? {
        return imageForObject(art)
    }
    
    public static func imageForCamp(_ camp: BRCCampObject) -> UIImage? {
        return imageForObject(camp)
    }
    
    public static func imageForObject(_ object: BRCDataObject & BRCThumbnailProtocol) -> UIImage? {
        let filename = self.fileName(object, type: .image)
        guard let bundle = Bundle.bundledMedia else {
            return nil
        }
        if let image = UIImage(named: filename, in: bundle, compatibleWith: nil) {
            return image
        }
        let cacheUrl = URL(fileURLWithPath: BRCMediaDownloader.mediaFilesPath)
        if let cacheBundle = Bundle(url: cacheUrl), let image = UIImage(named: filename, in: cacheBundle, compatibleWith: nil) {
            return image
        }
        return nil
    }
    
    func fileNameForObject(_ object: BRCDataObject) -> String {
        let fileName = BRCMediaDownloader.fileName(object, type: downloadType)
        return fileName
    }
    
    @objc public static func fileName(_ object: BRCDataObject, type: BRCMediaDownloadType) -> String {
        let fileType = extensionForDownloadType(type)
        let fileName =  "\(object.uniqueID).\(fileType)"
        return fileName
    }
    
    fileprivate static func extensionForDownloadType(_ type: BRCMediaDownloadType) -> String {
        switch type {
        case .image:
            return "jpg"
        case .audio:
            return "m4a"
        default:
            return ""
        }
    }
    
    /** This will cache un-downloaded media */
    public func downloadUncachedMedia() {
        BRCMediaDownloader.copyMediaFilesIfNeeded()
        connection.asyncRead { (transaction) in
            guard let viewTransaction = transaction.ext(self.viewName) as? YapDatabaseViewTransaction else {
                return
            }
            var dataObjects: [URL: BRCDataObject] = [:]
            viewTransaction.enumerateGroups({ (group, stop) -> Void in
                viewTransaction.iterateKeysAndObjects(inGroup: group) { (collection, key, object, index, stop) in
                    if let dataObject = object as? BRCDataObject {
                        // Only add files that haven't been downloaded
                        var remoteURL: URL? = nil
                        var localURL: URL? = nil
                        switch self.downloadType {
                        case .image:
                            if let thumbnailObject = dataObject as? BRCThumbnailProtocol {
                                remoteURL = thumbnailObject.remoteThumbnailURL
                                localURL = thumbnailObject.localThumbnailURL
                            }
                            break
                        case .audio:
                            if let artObject = dataObject as? BRCArtObject {
                                remoteURL = artObject.remoteAudioURL
                                localURL = artObject.localAudioURL
                            }
                            break
                        default:
                            break
                        }
                        
                        if localURL == nil && remoteURL == nil {
                            return
                        }
                        
                        if remoteURL != nil && localURL == nil {
                            DDLogInfo("Downloading media for \(dataObject.self) \(dataObject.uniqueID)  \(String(describing: remoteURL))")
                            dataObjects[remoteURL!] = dataObject
                        } else {
                            //NSLog("Already downloaded media for %@", remoteURL!)
                        }
                    }
                }
            })
            self.session.getTasksWithCompletionHandler({ (_, _, downloads) in
                // Remove things already being downloaded
                for download in downloads {
                    DDLogWarn("canceling existing download: \(download)")
                    download.cancel()
                }
                self.downloadFiles(Array(dataObjects.values))
            })
        }
    }
    
    fileprivate func remoteURL(_ file: BRCDataObject) -> URL? {
        switch downloadType {
        case .audio:
            if let artObject = file as? BRCArtObject {
                return artObject.remoteAudioURL
            }
            return nil
        case .image:
            if let thumbnailObject = file as? BRCThumbnailProtocol {
                return thumbnailObject.remoteThumbnailURL
            }
            return nil
        case .unknown:
            return nil
        }
    }
    
    fileprivate func downloadFiles(_ files: [BRCDataObject]) {
        backgroundTaskQueue.async {
            for file in files {
                guard let remoteURL = self.remoteURL(file) else {
                    DDLogError("No remote URL for file \(file)")
                    return
                }
                let task = self.session.downloadTask(with: remoteURL)
                let fileName = self.fileNameForObject(file)
                task.taskDescription = fileName
                DDLogInfo("Downloading file: \(String(describing: remoteURL))")
                let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: fileName, expirationHandler: {
                    NSLog("%@ task expired", fileName)
                })
                self.backgroundTasks[task.taskIdentifier] = backgroundTask
                task.resume()
            }
        }
    }
    
    private func triggerColorComputationForFile(_ fileName: String) {
        // Extract object ID from filename to find the corresponding object
        let objectID = String(fileName.prefix(fileName.count - 4)) // Remove .jpg extension
        
        connection.asyncRead { transaction in
            for collection in self.collections {
                if let obj = transaction.object(forKey: objectID, inCollection: collection) as? ThumbnailDataObject,
                   let metadata = obj.metadata(with: transaction) as? ColorableMetadata,
                   metadata.thumbnailImageColors == nil,
                   let image = BRCMediaDownloader.imageForObject(obj) {
                    DDLogInfo("Triggering color computation for \(String(describing: type(of: obj))): \(obj.title)")
                    ColorCache.shared.getColors(object: obj, metadata: metadata, image: image, downscaleSize: .zero, processingQueue: nil, completion: nil)
                    return
                }
            }
        }
    }
    
    //MARK: NSURLSessionDelegate
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        if let backgroundCompletion = backgroundCompletion {
            backgroundCompletion()
        }
        backgroundCompletion = nil
    }
    
    //MARK: NSURLSessionDownloadDelegate
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finishBackgroundTask(for: task)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        guard let fileName = downloadTask.taskDescription else {
            DDLogError("taskDescription is nil!")
            return
        }
        let destURL = BRCMediaDownloader.localCacheURL(fileName)
        do {
            try FileManager.default.moveItem(at: location, to: destURL)
            try (destURL as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
        } catch let error as NSError {
            DDLogError("Error moving file: \(error)")
            return
        }
        DDLogInfo("Media file cached: \(destURL)")
        
        // Trigger color computation for newly downloaded images
        if downloadType == .image {
            triggerColorComputationForFile(fileName)
        }
        
        finishBackgroundTask(for: downloadTask)
    }
    
    private func finishBackgroundTask(for downloadTask: URLSessionTask) {
        backgroundTaskQueue.async {
            if let backgroundTask = self.backgroundTasks[downloadTask.taskIdentifier] {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                self.backgroundTasks[downloadTask.taskIdentifier] = nil
                DDLogInfo("Ending background task found for \(downloadTask.taskIdentifier)")
            } else {
                DDLogWarn("No background task found for \(downloadTask.taskIdentifier)")
            }
        }
    }
}
