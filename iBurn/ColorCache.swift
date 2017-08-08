//
//  ColorCache.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/7/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import UIImageColors


public class ColorCache {
    static let shared = ColorCache()
    private let queue = DispatchQueue(label: "Color Cache Queue", attributes: .concurrent)
    private var cache: [Int:UIImageColors] = [:]
    private let mapTable = NSMapTable<NSNumber, BlockOperation>(keyOptions: [.strongMemory], valueOptions: [.strongMemory])
    private let operationQueue = OperationQueue()
    
    /** Cancels any outstanding color calculations for this image */
    func cancelColors(image: UIImage) {
        var existingOperation: BlockOperation? = nil
        let key = image.hash as NSNumber
        queue.sync {
            existingOperation = mapTable.object(forKey: key)
        }
        if let operation = existingOperation {
            self.queue.async(flags: .barrier) {
                operation.cancel()
                self.mapTable.removeObject(forKey: key)
            }
        }
    }
    
    /** Caches image color fetches, returns on main queue */
    func getColors(image: UIImage, completion: @escaping (UIImageColors) -> Void) {
        let hashValue = image.hash
        let key = hashValue as NSNumber
        var colors: UIImageColors? = nil
        var existingOperation: BlockOperation? = nil
        queue.sync {
            colors = cache[hashValue]
            existingOperation = mapTable.object(forKey: key)
        }
        if let colors = colors {
            DispatchQueue.main.async {
                completion(colors)
            }
            cancelColors(image: image)
            return
        }
        guard existingOperation == nil else {
            // Bail out if we've already got an operation for this
            return
        }
        let operation = BlockOperation()
        self.queue.async(flags: .barrier) {
            self.mapTable.setObject(operation, forKey: key)
        }
        operation.addExecutionBlock {
            var existingOperation: BlockOperation? = nil
            self.queue.sync {
                existingOperation = self.mapTable.object(forKey: key)
            }
            if let operation = existingOperation {
                if operation.isCancelled {
                    return
                }
            }
            let colors = image.getColors()
            DispatchQueue.main.async {
                completion(colors)
            }
            self.queue.async(flags: .barrier) {
                self.cache[hashValue] = colors
                self.mapTable.removeObject(forKey: key)
            }
        }
        operationQueue.addOperation(operation)
    }
    
}
