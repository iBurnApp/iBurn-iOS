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

public class MapRegionDataSource: NSObject, AnnotationDataSource {
    public var annotations: [MGLAnnotation] = []
    
    public func allAnnotations() -> [MGLAnnotation] {
        return annotations
    }
}

public class AggregateAnnotationDataSource: NSObject, AnnotationDataSource {
    let dataSources: [AnnotationDataSource]
    
    init(dataSources: [AnnotationDataSource]) {
        self.dataSources = dataSources
    }
    
    public func allAnnotations() -> [MGLAnnotation] {
        return dataSources.map { $0.allAnnotations() }.flatMap { $0 }
    }
}

extension YapViewAnnotationDataSource: AnnotationDataSource {
    public func allAnnotations() -> [MGLAnnotation] {
        var annotations: [MGLAnnotation] = []
        for section in 0..<viewHandler.numberOfSections {
            for row in 0..<viewHandler.numberOfItemsInSection(section) {
                let index = IndexPath(row: row, section: section)
                var annotation: DataObjectAnnotation?
                if let dataObject: BRCDataObject = viewHandler.object(at: index, readBlock: { (dataObject, t) in
                    annotation = dataObject.annotation(transaction: t)
                }),
                BRCEmbargo.canShowLocation(for: dataObject),
                    let annotation = annotation {
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
    func annotation(transaction: YapDatabaseReadTransaction) -> DataObjectAnnotation? {
        let metadata = self.metadata(with: transaction)
        return annotation(metadata: metadata)
    }
    
    func annotation(metadata: BRCObjectMetadata) -> DataObjectAnnotation? {
        return DataObjectAnnotation(object: self, metadata: metadata)
    }
}

/// This wrapper is required because MGLAnnotation has
/// different optionality requirements than BRCDataObject for `title`
public final class DataObjectAnnotation: NSObject {
    /// this value may be slightly changed to prevent data overlap
    public var coordinate: CLLocationCoordinate2D
    public let originalCoordinate: CLLocationCoordinate2D

    let object: BRCDataObject
    let metadata: BRCObjectMetadata
    @objc public init?(object: BRCDataObject, metadata: BRCObjectMetadata) {
        guard let location = object.location,
            CLLocationCoordinate2DIsValid(location.coordinate) else {
            return nil
        }
        self.coordinate = location.coordinate
        self.originalCoordinate = location.coordinate
        self.object = object
        self.metadata = metadata
    }
}

extension DataObjectAnnotation: MGLAnnotation {
    
    public var title: String? {
        var title = object.title
        if let event = object as? BRCEventObject {
            if let camp = event.campName {
                title += " @ \(camp)"
            } else if let art = event.artName {
                title += " @ \(art)"
            }
        }
        return title
    }
    
    public var subtitle: String? {
        var subtitle = ""
        if let location = object.playaLocation {
            subtitle += location
        }
        if let event = object as? BRCEventObject {
            if event.isHappeningRightNow(.present) {
                subtitle += " • \(event.startAndEndString)"
            } else {
                subtitle += " • \(event.startWeekdayString) \(event.startAndEndString)"
            }
        }
        if let userNotes = metadata.userNotes, !userNotes.isEmpty {
            subtitle += " - \(userNotes)"
        }
        return subtitle
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
