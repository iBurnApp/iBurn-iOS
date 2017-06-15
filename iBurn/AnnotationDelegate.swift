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

public class MapViewDelegate: NSObject, MGLMapViewDelegate {
    
//    public func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
//        guard let image = annotation.markerImage else {
//            return nil
//        }
//        let reuseIdentifier = "\(annotation.coordinate.longitude)"
//        let annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: reuseIdentifier) ?? MGLAnnotationImage(image: image, reuseIdentifier: reuseIdentifier)
//        annotationImage.image = image
//        return annotationImage
//    }
    
    public func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        guard let image = annotation.markerImage else {
            return nil
        }
        let reuseIdentifier = "\(annotation.coordinate.longitude)"
        var brcAnnotationView: BRCAnnotationView? = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? BRCAnnotationView
        if brcAnnotationView == nil {
            brcAnnotationView = BRCAnnotationView(reuseIdentifier: reuseIdentifier)
        }
        guard let annotationView = brcAnnotationView else {
            return nil
        }
        let imageFrame = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        annotationView.imageView.image = image
        annotationView.imageView.frame = imageFrame
        annotationView.frame = imageFrame
        return annotationView
    }
    
    public func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
}
