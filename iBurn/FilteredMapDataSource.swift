//
//  FilteredMapDataSource.swift
//  iBurn
//
//  Data source that combines PlayaDB annotations with YapDB user pins.
//

import Foundation
import YapDatabase
import CoreLocation
import PlayaDB

/// Data source that filters map annotations based on user preferences.
/// PlayaDB observations provide art/camp/event/favorites annotations reactively.
/// User pins (BRCUserMapPoint) still come from YapDatabase.
public class FilteredMapDataSource: NSObject, AnnotationDataSource {

    private let userDataSource: YapCollectionAnnotationDataSource
    private let playaDataSource: PlayaDBAnnotationDataSource

    /// Called on the main queue when PlayaDB observations push new data.
    var onAnnotationsChanged: (() -> Void)?

    init(playaDB: PlayaDB) {
        userDataSource = YapCollectionAnnotationDataSource(collection: BRCUserMapPoint.yapCollection)
        userDataSource.allowedClass = BRCUserMapPoint.self
        playaDataSource = PlayaDBAnnotationDataSource(playaDB: playaDB)
        super.init()
        playaDataSource.delegate = self
        playaDataSource.startObserving()
    }

    public func allAnnotations() -> [MLNAnnotation] {
        userDataSource.allAnnotations() + playaDataSource.allAnnotations()
    }

    /// Tear down and recreate observations with current UserSettings.
    func updateFilters() {
        playaDataSource.stopObserving()
        playaDataSource.startObserving()
    }
}

extension FilteredMapDataSource: PlayaDBAnnotationDataSourceDelegate {
    func annotationDataSourceDidUpdate(_ dataSource: PlayaDBAnnotationDataSource) {
        onAnnotationsChanged?()
    }
}
