//
//  FilteredMapDataSource.swift
//  iBurn
//
//  Data source that combines PlayaDB annotations with YapDB user pins.
//

import Foundation
import CoreLocation
import PlayaDB

/// Data source that filters map annotations based on user preferences.
/// PlayaDB observations provide art/camp/event/favorites annotations reactively.
/// User pins also come from PlayaDB.
public class FilteredMapDataSource: NSObject, AnnotationDataSource {

    private var userAnnotations: [BRCUserMapPoint] = []
    private var userPinObservation: PlayaDBObservationToken?
    private let playaDataSource: PlayaDBAnnotationDataSource

    /// Called on the main queue when PlayaDB observations push new data.
    var onAnnotationsChanged: (() -> Void)?

    init(playaDB: PlayaDB) {
        playaDataSource = PlayaDBAnnotationDataSource(playaDB: playaDB)
        super.init()
        playaDataSource.delegate = self
        playaDataSource.startObserving()

        userPinObservation = playaDB.observeUserMapPins { [weak self] pins in
            self?.userAnnotations = pins.map { BRCUserMapPoint(userMapPin: $0) }
            self?.onAnnotationsChanged?()
        }
    }

    public func allAnnotations() -> [MLNAnnotation] {
        userAnnotations + playaDataSource.allAnnotations()
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
