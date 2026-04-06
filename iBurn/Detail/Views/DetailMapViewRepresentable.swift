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
    private let annotationProvider: () -> MLNAnnotation?
    let onTap: () -> Void

    init(
        dataObject: BRCDataObject,
        metadata: BRCObjectMetadata?,
        onTap: @escaping () -> Void
    ) {
        self.annotationProvider = {
            DataObjectAnnotation(object: dataObject, metadata: metadata ?? BRCObjectMetadata())
        }
        self.onTap = onTap
    }

    init(
        annotation: MLNAnnotation,
        onTap: @escaping () -> Void
    ) {
        self.annotationProvider = { annotation }
        self.onTap = onTap
    }
    
    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView.brcMapView()
        mapView.isUserInteractionEnabled = false
        mapView.delegate = context.coordinator

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {
        guard let annotation = annotationProvider() else {
            return
        }

        let dataSource = StaticAnnotationDataSource(annotation: annotation)
        let mapViewAdapter = MapViewAdapter(mapView: uiView, dataSource: dataSource)
        mapViewAdapter.reloadAnnotations()
        context.coordinator.mapViewAdapter = mapViewAdapter
        context.coordinator.pendingAnnotation = annotation

        // If map is already loaded, zoom immediately; otherwise the delegate will handle it
        if context.coordinator.isMapLoaded {
            let padding = UIEdgeInsets(top: 45, left: 45, bottom: 45, right: 45)
            uiView.brc_showDestination(annotation, animated: true, padding: padding)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    class Coordinator: NSObject, MLNMapViewDelegate {
        let onTap: () -> Void
        var mapViewAdapter: MapViewAdapter?
        var pendingAnnotation: MLNAnnotation?
        var isMapLoaded = false

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap() {
            onTap()
        }

        func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
            isMapLoaded = true
            if let annotation = pendingAnnotation {
                let padding = UIEdgeInsets(top: 45, left: 45, bottom: 45, right: 45)
                mapView.brc_showDestination(annotation, animated: true, padding: padding)
                pendingAnnotation = nil
            }
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
