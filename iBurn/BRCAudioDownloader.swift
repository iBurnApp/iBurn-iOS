//
//  BRCAudioDownloader.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/8/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase

public class BRCAudioDownloader: NSObject, NSURLSessionDelegate, NSURLSessionDownloadDelegate {
    
    let viewName: String
    let connection: YapDatabaseConnection
    var session: NSURLSession!
    public static let backgroundSessionIdentifier = "BRCAudioDownloaderSession"
    var observer: NSObjectProtocol?
    public var backgroundCompletion: dispatch_block_t?
    
    deinit {
        if let observer = observer {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
    public init(connection: YapDatabaseConnection, viewName: String) {
        self.connection = connection
        self.viewName = viewName
        let config = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(BRCAudioDownloader.backgroundSessionIdentifier)
        super.init()
        self.session = NSURLSession(configuration: config, delegate: self, delegateQueue: NSOperationQueue.mainQueue())
        observer = NSNotificationCenter.defaultCenter().addObserverForName(BRCDatabaseExtensionRegisteredNotification, object: BRCDatabaseManager.sharedInstance(), queue: NSOperationQueue.mainQueue()) { (notification) in
            if let extensionName = notification.userInfo?["extensionName"] as? String {
                if extensionName == self.viewName {
                    NSLog("BRCAudioDownloader databaseExtensionRegistered: %@", extensionName)
                    self.downloadAudio()
                }
            }
        }
    }
    
    public static func downloadPath() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        let folderName = "AudioFiles"
        let path = documentsPath.stringByAppendingPathComponent(folderName)
        if !NSFileManager.defaultManager().fileExistsAtPath(path) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
            } catch {}
        }
        return path
    }
    
    public static func localAudioURL(art: BRCArtObject) -> NSURL {
        let downloadPath = self.downloadPath() as NSString
        let fileName = art.uniqueID + ".mp3"
        let path = downloadPath.stringByAppendingPathComponent(fileName)
        let url = NSURL(fileURLWithPath: path)
        return url
    }
    
    /** This will cache un-downloaded audio tracks */
    public func downloadAudio() {
        connection.asyncReadWithBlock { (transaction) in
            guard let viewTransaction = transaction.ext(self.viewName) as? YapDatabaseViewTransaction else {
                return
            }
            var art: [NSURL: BRCArtObject] = [:]
            viewTransaction.enumerateGroupsUsingBlock({ (group: String!, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                viewTransaction.enumerateKeysAndObjectsInGroup(group, usingBlock: { (collection: String!, key: String!, object: AnyObject!, index: UInt, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                    if let dataObject = object as? BRCArtObject {
                        // Only add files that haven't been downloaded
                        if dataObject.remoteAudioURL != nil && dataObject.localAudioURL == nil {
                            NSLog("Downloading audio for %@", dataObject.remoteAudioURL)
                            art[dataObject.remoteAudioURL] = dataObject
                        } else {
                            NSLog("Already downloaded audio for %@", dataObject.remoteAudioURL)
                        }
                    }
                })
            })
            self.session.getTasksWithCompletionHandler({ (_, _, downloads) in
                // Remove things already being downloaded
                for download in downloads {
                    if let url = download.originalRequest?.URL {
                        if let exists = art[url] {
                            NSLog("Existing download for %@", exists.remoteAudioURL)
                            art.removeValueForKey(url)
                        }
                    }
                }
                self.downloadFiles(Array(art.values))
                
            })
        }
    }
    
    private func downloadFiles(files: [BRCArtObject]) {
        for file in files {
            let task = self.session.downloadTaskWithURL(file.remoteAudioURL)
            task.taskDescription = file.uniqueID
            NSLog("Downloading file: %@", file.remoteAudioURL)
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
        guard let key = downloadTask.taskDescription else {
            NSLog("taskDescription is nil!")
            return
        }
        var object: AnyObject?
        self.connection.readWithBlock { (transaction) in
            object = transaction.objectForKey(key, inCollection: BRCArtObject.collection())
        }
        guard let artObject = object as? BRCArtObject else {
            NSLog("no artObject found!")
            return
        }
        let destURL = self.dynamicType.localAudioURL(artObject)
        do {
            try NSFileManager.defaultManager().moveItemAtURL(location, toURL: destURL)
            try destURL.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
        } catch let error as NSError {
            NSLog("Error moving file: %@", error)
            return
        }
        NSLog("Audio file cached: %@", destURL)
    }
    
}
