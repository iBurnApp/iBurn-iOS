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

/// This wrapper is required because MGLAnnotation has
/// different optionality requirements than BRCDataObject for `title`
public final class DataObjectAnnotation: NSObject {
    fileprivate let object: BRCDataObject
    @objc public init(object: BRCDataObject) {
        self.object = object
    }
}

extension DataObjectAnnotation: MGLAnnotation {
    public var coordinate: CLLocationCoordinate2D {
        return object.location?.coordinate ?? kCLLocationCoordinate2DInvalid
    }
    
    public var title: String? {
        var title = object.title
        if let event = object as? BRCEventObject {
            if let camp = event.campName {
                title = camp
            } else if let art = event.artName {
                title = art
            }
        }
        return title
    }
    
    public var subtitle: String? {
        return object.playaLocation
    }
}


/// Protocol for iBurn-specific annotations
public protocol ImageAnnotation: MGLAnnotation {
    var markerImage: UIImage? { get }
}

extension DataObjectAnnotation: ImageAnnotation {
    public var markerImage: UIImage? {
        return object.brc_markerImage
    }
}

extension BRCMapPoint: ImageAnnotation {
    public var markerImage: UIImage? {
        return image
    }
}
