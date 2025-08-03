//
//  TimeShiftMapView.swift
//  iBurn
//
//  Created by Claude Code on 8/3/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import MapLibre

struct TimeShiftMapView: UIViewRepresentable {
    @Binding var selectedLocation: CLLocation?
    @Binding var isLocationOverrideEnabled: Bool
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    
    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView.brcMapView()
        mapView.delegate = context.coordinator
        
        // Add tap gesture for location selection
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)
        
        // Show user location
        mapView.showsUserLocation = true
        
        // Center on BRC by default
        let brcCenter = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        mapView.setCenter(brcCenter, zoomLevel: 14, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MLNMapView, context: Context) {
        // Update annotation if location override is enabled
        context.coordinator.updateAnnotation(for: selectedLocation, on: mapView)
        
        // Enable/disable interaction based on override state
        mapView.isUserInteractionEnabled = isLocationOverrideEnabled
        mapView.alpha = isLocationOverrideEnabled ? 1.0 : 0.7
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, MLNMapViewDelegate {
        let parent: TimeShiftMapView
        var currentAnnotation: MLNPointAnnotation?
        
        init(parent: TimeShiftMapView) {
            self.parent = parent
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard parent.isLocationOverrideEnabled else { return }
            
            let mapView = gesture.view as! MLNMapView
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            parent.onLocationSelected(coordinate)
        }
        
        func updateAnnotation(for location: CLLocation?, on mapView: MLNMapView) {
            // Remove existing annotation
            if let existing = currentAnnotation {
                mapView.removeAnnotation(existing)
                currentAnnotation = nil
            }
            
            // Add new annotation if location is overridden
            if parent.isLocationOverrideEnabled, let location = location {
                let annotation = MLNPointAnnotation()
                annotation.coordinate = location.coordinate
                annotation.title = "Selected Location"
                mapView.addAnnotation(annotation)
                currentAnnotation = annotation
                
                // Center on the annotation
                mapView.setCenter(location.coordinate, zoomLevel: 15, animated: true)
            }
        }
        
        // MARK: - MLNMapViewDelegate
        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard annotation === currentAnnotation else { return nil }
            
            let reuseId = "time-shift-pin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
            
            if annotationView == nil {
                annotationView = MLNAnnotationView(reuseIdentifier: reuseId)
                annotationView?.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
                
                // Custom pin image or system image
                let config = UIImage.SymbolConfiguration(pointSize: 30)
                let image = UIImage(systemName: "mappin.circle.fill", withConfiguration: config)
                let imageView = UIImageView(image: image?.withTintColor(.systemOrange, renderingMode: .alwaysOriginal))
                imageView.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
                annotationView?.addSubview(imageView)
            }
            
            return annotationView
        }
    }
}