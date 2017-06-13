//
//  AnnotationDelegate.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/12/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import Mapbox

extension MGLAnnotation {
    var markerImage: UIImage? {
        var markerImage: UIImage? = nil
        if let dataObject = self as? BRCDataObject {
            markerImage = dataObject.markerImage
        } else if let mapPoint = self as? BRCMapPoint {
            markerImage = mapPoint.image
        }
        return markerImage ?? UIImage(named: "BRCPurplePin")
    }
}

public class ImageAnnotationDelegate: NSObject, MGLMapViewDelegate {
    let annotationIdentifier = "ImageIdentifier"
    
    public func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        guard let image = annotation.markerImage else {
            return nil
        }
        let annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: annotationIdentifier) ?? MGLAnnotationImage(image: image, reuseIdentifier: annotationIdentifier)
        annotationImage.image = image
        return annotationImage
    }
}

public class AnnotationDelegate: NSObject, MGLMapViewDelegate {
    let annotationIdentifier = "Identifier"
    
    public func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        guard let image = annotation.markerImage else {
            return nil
        }
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: annotationIdentifier) as? BRCAnnotationView ?? BRCAnnotationView(reuseIdentifier: annotationIdentifier)
        annotationView.imageView.image = image
        annotationView.imageView.sizeToFit()
        annotationView.sizeToFit()
        return annotationView
    }
}
