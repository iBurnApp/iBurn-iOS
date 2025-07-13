//
//  ZoomableImageView.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/13/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

import SwiftUI

// MARK: - Public SwiftUI View (Reusable Component)

/// A view that displays a UIImage within a zoomable and pannable view.
///
/// This view is the core component for displaying the interactive image. It should be
/// placed inside a container view that provides chrome, like a close button.
public struct ZoomableImageView: View {
    public let uiImage: UIImage
    
    // Zoom state
    @State private var zoomScale: CGFloat = 1.0
    @State private var previousZoomScale: CGFloat = 1.0
    @State private var zoomAnchor: UnitPoint = .center
    
    // Drag state for panning
    @State private var dragOffset: CGSize = .zero
    @State private var previousDragOffset: CGSize = .zero
    
    // Gesture states
    @GestureState private var pinchScale: CGFloat = 1.0
    @GestureState private var panOffset: CGSize = .zero
    
    // Internal state to track zoom level for disabling dismiss gestures
    private var isZoomed: Bool {
        zoomScale > 1.01
    }
    
    // Container size for calculations
    @State private var containerSize: CGSize = .zero
    
    // Calculate the scale needed to fit width
    private var fitScale: CGFloat {
        guard uiImage.size.width > 0, uiImage.size.height > 0, containerSize.width > 0, containerSize.height > 0 else { 
            return 1.0 
        }
        
        let widthScale = containerSize.width / uiImage.size.width
        let heightScale = containerSize.height / uiImage.size.height
        
        // Use the smaller scale to ensure the entire image fits
        return min(widthScale, heightScale)
    }
    
    // Current scale including gesture
    private var currentScale: CGFloat {
        zoomScale * pinchScale
    }
    
    // Current offset including gesture
    private var currentOffset: CGSize {
        CGSize(
            width: dragOffset.width + panOffset.width,
            height: dragOffset.height + panOffset.height
        )
    }
    
    public init(uiImage: UIImage) {
        self.uiImage = uiImage
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: geometry.size.width * max(currentScale, 1.0),
                        height: geometry.size.height * max(currentScale, 1.0)
                    )
                    .scaleEffect(currentScale / max(currentScale, 1.0))
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
            }
            .scrollDisabled(currentScale <= 1.01)
            .background(Color.clear)
            .onAppear {
                containerSize = geometry.size
                // Reset to fit scale
                zoomScale = 1.0
            }
            .onChange(of: geometry.size) { newSize in
                containerSize = newSize
            }
            .gesture(
                MagnificationGesture()
                    .updating($pinchScale) { value, scale, _ in
                        scale = value
                    }
                    .onEnded { value in
                        let newScale = zoomScale * value
                        zoomScale = max(1.0, min(newScale, 4.0))
                        previousZoomScale = zoomScale
                    }
            )
            .onTapGesture(count: 2) { location in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if zoomScale > 1.01 {
                        // Zoom out to fit
                        zoomScale = 1.0
                        dragOffset = .zero
                        previousDragOffset = .zero
                    } else {
                        // Zoom in to 2x
                        zoomScale = 2.0
                        
                        // Calculate zoom anchor from tap location
                        let normalizedX = location.x / geometry.size.width
                        let normalizedY = location.y / geometry.size.height
                        zoomAnchor = UnitPoint(x: normalizedX, y: normalizedY)
                    }
                }
            }
        }
        // Disable the sheet's swipe-to-dismiss when zoomed in
        .interactiveDismissDisabled(isZoomed)
        // Hide the sheet's drag indicator when zoomed for a cleaner look
        .presentationDragIndicator(isZoomed ? .hidden : .visible)
    }
}

// MARK: - Example Sheet Implementation

/// A complete sheet view that hosts the ZoomableImageView and adds a close button.
struct ImageViewerSheet: View {
    let image: UIImage
    
    // Environment property to dismiss the sheet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // The main interactive image viewer
        ZoomableImageView(uiImage: image)
            // The following modifiers are on the content *inside* the sheet
            .presentationBackground(.ultraThinMaterial)
            .presentationDetents([.large])
            .overlay(alignment: .topTrailing) {
                // Close Button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .padding()
            }
    }
}