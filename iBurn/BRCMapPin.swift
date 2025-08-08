//
//  BRCMapPin.swift
//  iBurn
//
//  Created by iBurn Development Team on 8/8/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

import Foundation
import CoreLocation
import YapDatabase

@objc class BRCMapPin: BRCDataObject {
    
    @objc dynamic var color: String = "red"
    @objc dynamic var createdDate: Date = Date()
    @objc dynamic var notes: String?
    
    override class var yapCollection: String {
        return "BRCMapPinCollection"
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        self.year = NSNumber(value: YearSettings.current.year)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        color = coder.decodeObject(forKey: "color") as? String ?? "red"
        createdDate = coder.decodeObject(forKey: "createdDate") as? Date ?? Date()
        notes = coder.decodeObject(forKey: "notes") as? String
    }
    
    // MARK: - NSCoding
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(color, forKey: "color")
        coder.encode(createdDate, forKey: "createdDate")
        coder.encode(notes, forKey: "notes")
    }
    
    // MARK: - Mantle
    
    override class func jsonKeyPathsByPropertyKey() -> [AnyHashable : Any]! {
        var mappings = super.jsonKeyPathsByPropertyKey() ?? [:]
        mappings["color"] = "color"
        mappings["createdDate"] = "created_date"
        mappings["notes"] = "notes"
        return mappings
    }
    
    override class func createdDateJSONTransformer() -> ValueTransformer? {
        return MTLValueTransformer.transformerUsingForwardBlock({ value, success, error in
            guard let dateString = value as? String else { return nil }
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: dateString)
        }, reverseBlock: { value, success, error in
            guard let date = value as? Date else { return nil }
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: date)
        })
    }
}