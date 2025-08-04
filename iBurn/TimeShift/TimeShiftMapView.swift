//
//  TimeShiftMapView.swift
//  iBurn
//
//  Created by Claude Code on 8/3/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import MapLibre

struct TimeShiftMapView: View {
    @Binding var selectedLocation: CLLocation?
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    @State private var mapViewRef: MLNMapView?
    
    var body: some View {
        TimeShiftMapRepresentable(
            selectedLocation: $selectedLocation,
            onLocationSelected: onLocationSelected,
            mapViewRef: $mapViewRef
        )
        .overlay(alignment: .topTrailing) {
            if selectedLocation != nil {
                Button("Clear Location") {
                    withAnimation {
                        selectedLocation = nil
                        // Always zoom to BRC when clearing
                        mapViewRef?.brc_zoomToFullTileSource(animated: true)
                    }
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
    }
}

struct TimeShiftMapRepresentable: UIViewRepresentable {
    @Binding var selectedLocation: CLLocation?
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    @Binding var mapViewRef: MLNMapView?
    
    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView.brcMapView()
        mapView.delegate = context.coordinator
        
        // Store reference to map
        DispatchQueue.main.async {
            mapViewRef = mapView
        }
        
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
        // Update annotation whenever location changes
        context.coordinator.updateAnnotation(for: selectedLocation, on: mapView)
        
        // Map is always interactive and fully visible
        mapView.isUserInteractionEnabled = true
        mapView.alpha = 1.0
        
        // Don't auto-zoom - let user control the view
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, MLNMapViewDelegate {
        let parent: TimeShiftMapRepresentable
        var currentAnnotation: MLNPointAnnotation?
        
        init(parent: TimeShiftMapRepresentable) {
            self.parent = parent
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
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
            
            // Add new annotation if we have a location
            if let location = location {
                let annotation = MLNPointAnnotation()
                annotation.coordinate = location.coordinate
                annotation.title = "Warped Location"
                annotation.subtitle = String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude)
                mapView.addAnnotation(annotation)
                currentAnnotation = annotation
            }
        }
        
        func fitMapToShowBothLocations(mapView: MLNMapView, selectedLocation: CLLocation) {
            guard let userLocation = mapView.userLocation?.location else {
                // If no user location yet, just center on selected location
                mapView.setCenter(selectedLocation.coordinate, zoomLevel: 15, animated: true)
                return
            }
            
            // Calculate bounds that include both locations
            let minLat = min(userLocation.coordinate.latitude, selectedLocation.coordinate.latitude)
            let maxLat = max(userLocation.coordinate.latitude, selectedLocation.coordinate.latitude)
            let minLon = min(userLocation.coordinate.longitude, selectedLocation.coordinate.longitude)
            let maxLon = max(userLocation.coordinate.longitude, selectedLocation.coordinate.longitude)
            
            // Add some padding
            let latPadding = (maxLat - minLat) * 0.2
            let lonPadding = (maxLon - minLon) * 0.2
            
            let sw = CLLocationCoordinate2D(latitude: minLat - latPadding, longitude: minLon - lonPadding)
            let ne = CLLocationCoordinate2D(latitude: maxLat + latPadding, longitude: maxLon + lonPadding)
            let bounds = MLNCoordinateBounds(sw: sw, ne: ne)
            
            // Fit the map to show both locations
            let edgePadding = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
            mapView.setVisibleCoordinateBounds(bounds, edgePadding: edgePadding, animated: true, completionHandler: nil)
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