import Foundation
import PlayaAPI

/// Bridges `update.json` (PlayaAPI's `UpdateInfo`, keyed by the server's file names)
/// to PlayaDB's `DataObjectType`, so the same "is this newer than what we imported?"
/// comparison serves both the bundled dataset and over-the-air updates.
public extension APIUpdateInfo {
    /// The per-type entries present in this update.json, in import order.
    /// Types the file doesn't mention are omitted.
    var fileInfoByDataType: [(type: DataObjectType, info: FileUpdateInfo)] {
        var result: [(type: DataObjectType, info: FileUpdateInfo)] = []
        if let art { result.append((.art, art)) }
        if let camps { result.append((.camp, camps)) }
        if let events { result.append((.event, events)) }
        if let mv { result.append((.mutantVehicle, mv)) }
        return result
    }

    /// The entry describing `type`, if this update.json mentions it.
    func fileInfo(for type: DataObjectType) -> FileUpdateInfo? {
        switch type {
        case .art: return art
        case .camp: return camps
        case .event: return events
        case .mutantVehicle: return mv
        }
    }
}
