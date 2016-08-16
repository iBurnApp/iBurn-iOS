//
//  BRCMediaDownloader.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/8/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase

@objc
public enum BRCMediaDownloadType: Int
{
    case Unknown = 0
    case Audio
    case Image
}

public class BRCMediaDownloader: NSObject, NSURLSessionDelegate, NSURLSessionDownloadDelegate {
    
    let viewName: String
    let connection: YapDatabaseConnection
    var session: NSURLSession!
    
    let downloadType: BRCMediaDownloadType
    public let backgroundSessionIdentifier: String
    var observer: NSObjectProtocol?
    public var backgroundCompletion: dispatch_block_t?
    let delegateQueue = NSOperationQueue()
    
    deinit {
        if let observer = observer {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
    public init(connection: YapDatabaseConnection, viewName: String, downloadType: BRCMediaDownloadType) {
        self.downloadType = downloadType
        self.connection = connection
        self.viewName = viewName
        self.backgroundSessionIdentifier = "BRCMediaDownloaderSession" + viewName
        let config = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(backgroundSessionIdentifier)
        super.init()
        self.session = NSURLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
        observer = NSNotificationCenter.defaultCenter().addObserverForName(BRCDatabaseExtensionRegisteredNotification, object: BRCDatabaseManager.sharedInstance(), queue: NSOperationQueue.mainQueue()) { (notification) in
            if let extensionName = notification.userInfo?["extensionName"] as? String {
                if extensionName == self.viewName {
                    NSLog("BRCMediaDownloader databaseExtensionRegistered: %@", extensionName)
                    self.downloadUncachedMedia()
                }
            }
        }
    }
    
    public static func downloadPath() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        let folderName = "MediaFiles"
        let path = documentsPath.stringByAppendingPathComponent(folderName)
        if !NSFileManager.defaultManager().fileExistsAtPath(path) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
            } catch {}
        }
        return path
    }
    
    public static func localMediaURL(fileName: String) -> NSURL {
        let downloadPath = self.downloadPath() as NSString
        let path = downloadPath.stringByAppendingPathComponent(fileName)
        let url = NSURL(fileURLWithPath: path)
        return url
    }
    
    public static func fileName(art: BRCArtObject, type: BRCMediaDownloadType) -> String {
        let fileType = extensionForDownloadType(type)
        let fileName = (art.uniqueID as NSString).stringByAppendingPathExtension(fileType)!
        return fileName
    }
    
    private static func extensionForDownloadType(type: BRCMediaDownloadType) -> String {
        switch type {
        case .Image:
            return "jpg"
        case .Audio:
            return "mp3"
        default:
            return ""
        }
    }
    
    /** This will cache un-downloaded media */
    public func downloadUncachedMedia() {
        connection.asyncReadWithBlock { (transaction) in
            guard let viewTransaction = transaction.ext(self.viewName) as? YapDatabaseViewTransaction else {
                return
            }
            var art: [NSURL: BRCArtObject] = [:]
            viewTransaction.enumerateGroupsUsingBlock({ (group: String!, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                viewTransaction.enumerateKeysAndObjectsInGroup(group, usingBlock: { (collection: String!, key: String!, object: AnyObject!, index: UInt, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                    if let dataObject = object as? BRCArtObject {
                        
                        // Only add files that haven't been downloaded
                        var remoteURL: NSURL? = nil
                        var localURL: NSURL? = nil
                        switch self.downloadType {
                        case .Image:
                            remoteURL = dataObject.remoteThumbnailURL
                            localURL = dataObject.localThumbnailURL
                            break
                        case .Audio:
                            remoteURL = dataObject.remoteAudioURL
                            localURL = dataObject.localAudioURL
                            break
                        default:
                            break
                        }
                        
                        if localURL == nil && remoteURL == nil {
                            return
                        }
                        
                        if remoteURL != nil && localURL == nil {
                            NSLog("Downloading media for %@", remoteURL!)
                            art[remoteURL!] = dataObject
                        } else {
                            //NSLog("Already downloaded media for %@", remoteURL!)
                        }
                    }
                })
            })
            self.session.getTasksWithCompletionHandler({ (_, _, downloads) in
                // Remove things already being downloaded
                for download in downloads {
                    if let url = download.originalRequest?.URL {
                        if let exists = art[url] {
                            NSLog("Existing download for %@", exists.url)
                            art.removeValueForKey(url)
                        }
                    }
                }
                self.downloadFiles(Array(art.values))
            })
        }
    }
    
    private func remoteURL(file: BRCArtObject) -> NSURL {
        switch downloadType {
        case .Audio:
            return file.remoteAudioURL
        case .Image:
            return file.remoteThumbnailURL
        default:
            return NSURL()
        }
    }
    
    private func downloadFiles(files: [BRCArtObject]) {
        for file in files {
            let remoteURL = self.remoteURL(file)
            let task = self.session.downloadTaskWithURL(remoteURL)
            let fileName = self.dynamicType.fileName(file, type: downloadType)
            task.taskDescription = fileName
            NSLog("Downloading file: %@", remoteURL)
            task.resume()
        }
    }
    
    //MARK: NSURLSessionDelegate
    public func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        if let backgroundCompletion = backgroundCompletion {
            backgroundCompletion()
        }
        backgroundCompletion = nil
    }
    
    //MARK: NSURLSessionDownloadDelegate
    
    public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        guard let fileName = downloadTask.taskDescription else {
            NSLog("taskDescription is nil!")
            return
        }
        let destURL = self.dynamicType.localMediaURL(fileName)
        do {
            try NSFileManager.defaultManager().moveItemAtURL(location, toURL: destURL)
            try destURL.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
        } catch let error as NSError {
            NSLog("Error moving file: %@", error)
            return
        }
        NSLog("Media file cached: %@", destURL)
    }
    
}
