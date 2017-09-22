//
//  APIObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 9/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation

public class APIObject: YapObject {
    
    var name: String = ""
    
    public convenience init(name: String) {
        self.init()
        self.name = name
    }
}

public class CampObject: APIObject {
    let camp = "camp"
}

public class ArtObject: APIObject {
    let artist = "artist"
}

public class EventObject: APIObject {
    let event = "event"
}
