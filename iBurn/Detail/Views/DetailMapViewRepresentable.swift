//
//  DetailMapViewRepresentable.swift
//  iBurn
//
//  Created by Claude Code on 7/13/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import MapLibre

/// SwiftUI wrapper for MLNMapView to display embedded map previews in DetailView
struct DetailMapViewRepresentable: UIViewRepresentable {
    let dataObject: BRCDataObject
    let metadata: BRCObjectMetadata?
    let onTap: () -> Void
    
    func makeUIView(context: Context) -> MLNMapView {
        // Create map view with iBurn defaults
        let mapView = MLNMapView.brcMapView()
        
        // Create annotation for the data object
        guard let annotation = DataObjectAnnotation(object: dataObject, metadata: metadata ?? BRCObjectMetadata()) else {
            // If annotation creation fails, return empty map view
            mapView.isUserInteractionEnabled = false
            return mapView
        }
        
        // Create static data source with single annotation
        let dataSource = StaticAnnotationDataSource(annotation: annotation)
        
        // Create map view adapter to handle annotations
        let mapViewAdapter = MapViewAdapter(mapView: mapView, dataSource: dataSource)
        mapViewAdapter.reloadAnnotations()
        
        // Disable user interaction for preview mode
        mapView.isUserInteractionEnabled = false
        
        // Add tap gesture recognizer for navigation
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        mapView.addGestureRecognizer(tapGesture)
        
        // Store references in coordinator for later access
        context.coordinator.mapViewAdapter = mapViewAdapter
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {
        // Map content is static for detail views, no updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }
    
    class Coordinator: NSObject {
        let onTap: () -> Void
        var mapViewAdapter: MapViewAdapter?
        
        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }
        
        @objc func handleTap() {
            onTap()
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct DetailMapViewRepresentable_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Map Preview")
                .font(.headline)
            
            Text("Map component requires real data objects")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(height: 200)
                .border(Color.gray, width: 1)
            
            Text("Tap the map to navigate")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
#endif