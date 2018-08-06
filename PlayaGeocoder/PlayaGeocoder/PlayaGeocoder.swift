//
//  PlayaGeocoder.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/5/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import JavaScriptCore

public final class PlayaGeocoder: NSObject {
    // MARK: - Properties
    @objc public static let shared = PlayaGeocoder()
    private let context = JSContext()
    private let queue = DispatchQueue(label: "Geocoder Queue")
    
    // MARK: - Init

    public override init() {
        super.init()
        setupContext()
    }
    
    // MARK: - Public API
    
    /// WARN: This function may block during initialization
    @objc public func syncForwardLookup(_ address: String) -> CLLocationCoordinate2D {
        var coordinate = kCLLocationCoordinate2DInvalid
        queue.sync {
            coordinate = self.forwardLookup(address)
        }
        return coordinate
    }
    
    /// WARN: This function may block during initialization
    @objc public func syncReverseLookup(_ coordinate: CLLocationCoordinate2D) -> String? {
        var address: String?
        queue.sync {
            address = self.reverseLookup(coordinate)
        }
        return address
    }
    
    @objc public func asyncForwardLookup(_ address: String,
                                         completionQueue: DispatchQueue = DispatchQueue.main,
                                         completion: @escaping (CLLocationCoordinate2D)->Void) {
        queue.async {
            let coordinate = self.forwardLookup(address)
            completionQueue.async {
                completion(coordinate)
            }
        }
    }
    
    @objc public func asyncReverseLookup(_ coordinate: CLLocationCoordinate2D,
                                         completionQueue: DispatchQueue = DispatchQueue.main,
                                         completion: @escaping (String?)->Void) {
        queue.async {
            let address = self.reverseLookup(coordinate)
            completionQueue.async {
                completion(address)
            }
        }
    }
}

private extension PlayaGeocoder {
    func setupContext() {
        context?.exceptionHandler = { (context, exception) in
            if let exception = exception {
                NSLog("Geocoder exception: \(exception)")
            }
        }
        guard let path = Bundle(for: PlayaGeocoder.self).path(forResource: "bundle", ofType: "js"),
            let file = try? String(contentsOfFile: path) else {
            return
        }
        let _ = context?.evaluateScript("var window = this")
        let _ = context?.evaluateScript(file)
        let _ = context?.evaluateScript("var geocoder = prepare()")
    }
    
    /// Call this only on internal queue
    func reverseLookup(_ coordinate: CLLocationCoordinate2D) -> String? {
        guard CLLocationCoordinate2DIsValid(coordinate),
            let result = self.context?.evaluateScript("reverseGeocode(geocoder, \(coordinate.latitude), \(coordinate.longitude))"),
        result.isString,
        let string = result.toString() else {
            return nil
        }
        return string
    }
    
    /// Call this only on internal queue
    func forwardLookup(_ address: String) -> CLLocationCoordinate2D {
        guard let result = self.context?.evaluateScript("forwardGeocode(geocoder, \"\(address)\")"),
        let dict = result.toDictionary(),
        let geometry = dict["geometry"] as? [AnyHashable: Any],
        let coordinates = geometry["coordinates"] else {
                return kCLLocationCoordinate2DInvalid
        }
        var coordinatesArray: [Double] = []
        if let coordinates = coordinates as? [Double] {
            coordinatesArray = coordinates
        } else if let coordinates = coordinates as? [[Double]],
            let first = coordinates.first {
            coordinatesArray = first
        }
        
        var coordinate = kCLLocationCoordinate2DInvalid
        if let latitude = coordinatesArray.last,
            let longitude = coordinatesArray.first,
            latitude != 0,
            longitude != 0 {
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        return coordinate
    }
}
