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
        // Create map view with iBurn defaults (no side effects)
        let mapView = MLNMapView.brcMapView()
        mapView.isUserInteractionEnabled = false
        
        // Add tap gesture recognizer for navigation
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {
        // Always update annotation when called (handles data changes)
        guard let annotation = DataObjectAnnotation(object: dataObject, metadata: metadata ?? BRCObjectMetadata()) else {
            return
        }
        
        // Create fresh data source and adapter for current data
        let dataSource = StaticAnnotationDataSource(annotation: annotation)
        let mapViewAdapter = MapViewAdapter(mapView: uiView, dataSource: dataSource)
        mapViewAdapter.reloadAnnotations()
        context.coordinator.mapViewAdapter = mapViewAdapter
        
        // Always perform zoom for current data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let padding = UIEdgeInsets(top: 45, left: 45, bottom: 45, right: 45)
            uiView.brc_showDestination(for: dataObject, metadata: metadata ?? BRCObjectMetadata(), animated: true, padding: padding)
        }
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