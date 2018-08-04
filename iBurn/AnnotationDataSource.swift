//
//  AnnotationDataSource.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/3/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

@objc public protocol AnnotationDataSource: NSObjectProtocol {
    func allAnnotations() -> [MGLAnnotation]
}

public class SingleAnnotationDataSource: NSObject {
    public let annotation: MGLAnnotation
    
    @objc public init(annotation: MGLAnnotation) {
        self.annotation = annotation
    }
}

extension SingleAnnotationDataSource: AnnotationDataSource {
    public func allAnnotations() -> [MGLAnnotation] {
        return [annotation]
    }
}

public class UserAnnotationDataSource: NSObject {
    let uiConnection: YapDatabaseConnection
    
    override init() {
        uiConnection = BRCDatabaseManager.shared.uiConnection
    }
}

extension UserAnnotationDataSource: AnnotationDataSource {
    public func allAnnotations() -> [MGLAnnotation] {
        var userAnnotations: [BRCMapPoint] = []
        uiConnection.read({ transaction in
            transaction.enumerateKeysAndObjects(inCollection: BRCUserMapPoint.yapCollection, using: { (key, object, stop) in
                if let mapPoint = object as? BRCUserMapPoint {
                    userAnnotations.append(mapPoint)
                }
            })
        })
        return userAnnotations
    }
}
