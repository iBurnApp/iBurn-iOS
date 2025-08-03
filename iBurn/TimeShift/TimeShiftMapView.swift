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
        mapView.isUserInteractionEnabled = true // Always allow interaction
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
                annotation.subtitle = String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude)
                mapView.addAnnotation(annotation)
                currentAnnotation = annotation
                
                // Center on the annotation with slight delay to ensure visibility
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    mapView.setCenter(location.coordinate, zoomLevel: 16, animated: true)
                }
            }
        }
        
        // MARK: - MLNMapViewDelegate
        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard annotation === currentAnnotation else { return nil }
            
            let reuseId = "time-shift-pin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
            
            if annotationView == nil {
                annotationView = MLNAnnotationView(reuseIdentifier: reuseId)
                annotationView?.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
                
                // Create a more visible pin with shadow
                let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
                let image = UIImage(systemName: "mappin.circle.fill", withConfiguration: config)
                let imageView = UIImageView(image: image?.withTintColor(.systemOrange, renderingMode: .alwaysOriginal))
                imageView.frame = CGRect(x: 4, y: 4, width: 36, height: 36)
                imageView.layer.shadowColor = UIColor.black.cgColor
                imageView.layer.shadowOffset = CGSize(width: 0, height: 2)
                imageView.layer.shadowOpacity = 0.3
                imageView.layer.shadowRadius = 2
                annotationView?.addSubview(imageView)
                
                // Add pulsing animation
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.duration = 1.0
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.2
                pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                pulseAnimation.autoreverses = true
                pulseAnimation.repeatCount = .infinity
                imageView.layer.add(pulseAnimation, forKey: "pulse")
            }
            
            return annotationView
        }
    }
}