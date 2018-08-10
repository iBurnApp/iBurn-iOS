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

public class StaticAnnotationDataSource: NSObject {
    public let annotations: [MGLAnnotation]
    
    @objc public init(annotations: [MGLAnnotation]) {
        self.annotations = annotations
    }
    
    @objc public convenience init(annotation: MGLAnnotation) {
        self.init(annotations: [annotation])
    }
}

extension StaticAnnotationDataSource: AnnotationDataSource {
    public func allAnnotations() -> [MGLAnnotation] {
        return annotations
    }
}

public class YapViewAnnotationDataSource: NSObject {
    private let viewHandler: YapViewHandler
    
    init(viewHandler: YapViewHandler) {
        self.viewHandler = viewHandler
    }
}

public class YapCollectionAnnotationDataSource: NSObject {
    public let collection: String
    public var allowedClass = NSObject.self
    private let uiConnection: YapDatabaseConnection
    
    init(collection: String,
         uiConnection: YapDatabaseConnection = BRCDatabaseManager.shared.uiConnection) {
        self.uiConnection = uiConnection
        self.collection = collection
    }
}

extension YapViewAnnotationDataSource: AnnotationDataSource {
    public func allAnnotations() -> [MGLAnnotation] {
        var annotations: [MGLAnnotation] = []
        for section in 0..<viewHandler.numberOfSections {
            for row in 0..<viewHandler.numberOfItemsInSection(section) {
                let index = IndexPath(row: row, section: section)
                if let dataObject: BRCDataObject = viewHandler.object(at: index),
                    let annotation = dataObject.annotation {
                    annotations.append(annotation)
                }
            }
        }
        return annotations
    }
}

extension YapCollectionAnnotationDataSource: AnnotationDataSource {
    public func allAnnotations() -> [MGLAnnotation] {
        var annotations: [MGLAnnotation] = []
        uiConnection.read({ transaction in
            transaction.enumerateKeysAndObjects(inCollection: self.collection, using: { (key, object, stop) in
                guard let nsObject = object as? NSObject,
                    nsObject.isKind(of: self.allowedClass) else {
                    return
                }
                if let annotation = object as? MGLAnnotation {
                    annotations.append(annotation)
                }
            })
        })
        return annotations
    }
}

public extension BRCDataObject {
    var annotation: DataObjectAnnotation? {
        return DataObjectAnnotation(object: self)
    }
}

/// This wrapper is required because MGLAnnotation has
/// different optionality requirements than BRCDataObject for `title`
public final class DataObjectAnnotation: NSObject {
    let object: BRCDataObject
    @objc public init?(object: BRCDataObject) {
        guard let location = object.location,
            CLLocationCoordinate2DIsValid(location.coordinate) else {
            return nil
        }
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
