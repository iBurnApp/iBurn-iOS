//
//  LegacyDataStore.swift
//  iBurn
//
//  Created by Codex on 1/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import MapLibre
import PlayaDB
import YapDatabase

final class LegacyDataStore: LegacyFavoritesStoring {
    private let databaseManager: BRCDatabaseManager

    init(databaseManager: BRCDatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    func dataObject(for uid: String, type: DataObjectType) -> BRCDataObject? {
        var object: BRCDataObject?
        databaseManager.uiConnection.read { transaction in
            object = self.dataObject(for: uid, type: type, transaction: transaction)
        }
        return object
    }

    func favoriteIDs(for type: DataObjectType) async -> Set<String> {
        guard let collection = collectionName(for: type) else { return [] }

        return await withCheckedContinuation { continuation in
            databaseManager.backgroundReadConnection.asyncRead { transaction in
                var ids = Set<String>()
                transaction.iterateKeysAndObjects(inCollection: collection) { (key: String, _: Any, _: inout Bool) in
                    if let metadata = transaction.metadata(forKey: key, inCollection: collection) as? BRCObjectMetadata,
                       metadata.isFavorite {
                        ids.insert(key)
                    }
                }
                continuation.resume(returning: ids)
            }
        }
    }

    func updateFavoriteStatus(uid: String, type: DataObjectType, isFavorite: Bool) async {
        guard let collection = collectionName(for: type) else { return }

        await withCheckedContinuation { continuation in
            databaseManager.readWriteConnection.asyncReadWrite { transaction in
                guard let object = transaction.object(forKey: uid, inCollection: collection) as? BRCDataObject else {
                    return
                }
                let metadata = object.metadata(with: transaction).metadataCopy()
                metadata.isFavorite = isFavorite
                object.replace(metadata, transaction: transaction)
                if let event = object as? BRCEventObject {
                    event.refreshCalendarEntry(transaction)
                }
            } completionBlock: {
                continuation.resume()
            }
        }
    }

    func annotations(for artObjects: [ArtObject]) -> [MLNAnnotation] {
        annotations(for: .art, uids: artObjects.map(\.uid))
    }

    func annotations(for campObjects: [CampObject]) -> [MLNAnnotation] {
        annotations(for: .camp, uids: campObjects.map(\.uid))
    }

    // MARK: - Private Helpers

    private func annotations(for type: DataObjectType, uids: [String]) -> [MLNAnnotation] {
        let uniqueIDs = Array(Set(uids))
        guard !uniqueIDs.isEmpty else { return [] }

        var annotations: [MLNAnnotation] = []
        databaseManager.uiConnection.read { transaction in
            for uid in uniqueIDs {
                guard let object = self.dataObject(for: uid, type: type, transaction: transaction) else { continue }
                guard BRCEmbargo.canShowLocation(for: object) else { continue }
                let metadata = object.metadata(with: transaction)
                if let annotation = DataObjectAnnotation(object: object, metadata: metadata) {
                    annotations.append(annotation)
                }
            }
        }
        return annotations
    }

    private func dataObject(
        for uid: String,
        type: DataObjectType,
        transaction: YapDatabaseReadTransaction
    ) -> BRCDataObject? {
        switch type {
        case .art:
            return transaction.object(forKey: uid, inCollection: BRCArtObject.yapCollection) as? BRCArtObject
        case .camp:
            return transaction.object(forKey: uid, inCollection: BRCCampObject.yapCollection) as? BRCCampObject
        case .event:
            return transaction.object(forKey: uid, inCollection: BRCEventObject.yapCollection) as? BRCEventObject
        }
    }

    private func collectionName(for type: DataObjectType) -> String? {
        switch type {
        case .art:
            return BRCArtObject.yapCollection
        case .camp:
            return BRCCampObject.yapCollection
        case .event:
            return BRCEventObject.yapCollection
        }
    }
}
