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
    @State private var steadyStateZoomScale: CGFloat = 1.0
    @GestureState private var gestureZoomScale: CGFloat = 1.0
    
    // Pan state  
    @State private var steadyStatePanOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero
    
    // Internal state to track zoom level for disabling dismiss gestures
    private var isZoomed: Bool {
        currentZoomScale > 1.01
    }
    
    // Container size for calculations
    @State private var containerSize: CGSize = .zero
    
    // Combined zoom scale
    private var currentZoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    // Combined pan offset
    private var currentPanOffset: CGSize {
        CGSize(
            width: steadyStatePanOffset.width + gesturePanOffset.width,
            height: steadyStatePanOffset.height + gesturePanOffset.height
        )
    }
    
    public init(uiImage: UIImage) {
        self.uiImage = uiImage
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(currentZoomScale)
                    .offset(currentPanOffset)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        steadyStateZoomScale > 1.01 ?
                        DragGesture()
                            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                                gesturePanOffset = latestDragGestureValue.translation
                            }
                            .onEnded { dragGestureValue in
                                steadyStatePanOffset = CGSize(
                                    width: steadyStatePanOffset.width + dragGestureValue.translation.width,
                                    height: steadyStatePanOffset.height + dragGestureValue.translation.height
                                )
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    validatePanOffset()
                                }
                            }
                        : nil
                    )
                    .gesture(
                        // Magnification for pinch-to-zoom
                        MagnificationGesture()
                            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                                gestureZoomScale = latestGestureScale
                            }
                            .onEnded { gestureScaleAtEnd in
                                steadyStateZoomScale *= gestureScaleAtEnd
                                steadyStateZoomScale = max(1.0, min(steadyStateZoomScale, 3.0))
                                
                                // If we're back at 1x zoom, reset the pan offset
                                if steadyStateZoomScale <= 1.01 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        steadyStatePanOffset = .zero
                                    }
                                } else {
                                    // Validate pan bounds
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        validatePanOffset()
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) { location in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if steadyStateZoomScale > 1.01 {
                                // Zoom out to fit
                                steadyStateZoomScale = 1.0
                                steadyStatePanOffset = .zero
                            } else {
                                // Zoom in to 2x at tap location
                                let zoomPoint = CGPoint(
                                    x: location.x - geometry.size.width / 2,
                                    y: location.y - geometry.size.height / 2
                                )
                                
                                steadyStateZoomScale = 2.0
                                
                                // Offset to center on tap point
                                steadyStatePanOffset = CGSize(
                                    width: -zoomPoint.x,
                                    height: -zoomPoint.y
                                )
                                
                                validatePanOffset()
                            }
                        }
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .onAppear {
                containerSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                containerSize = newSize
                // Re-validate pan offset when container size changes
                if steadyStateZoomScale > 1.01 {
                    withAnimation {
                        validatePanOffset()
                    }
                }
            }
        }
        // Disable the sheet's swipe-to-dismiss when zoomed in
        .interactiveDismissDisabled(isZoomed)
        // Hide the sheet's drag indicator when zoomed for a cleaner look
        .presentationDragIndicator(isZoomed ? .hidden : .visible)
    }
    
    private func validatePanOffset() {
        // Calculate the scaled image size
        let _ = uiImage.size.width * steadyStateZoomScale
        let _ = uiImage.size.height * steadyStateZoomScale
        
        // Calculate the aspect ratios to determine actual displayed size
        let imageAspectRatio = uiImage.size.width / uiImage.size.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        var displayedImageSize: CGSize
        
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container - fit to width
            let scale = containerSize.width / uiImage.size.width
            displayedImageSize = CGSize(
                width: containerSize.width * steadyStateZoomScale,
                height: uiImage.size.height * scale * steadyStateZoomScale
            )
        } else {
            // Image is taller than container - fit to height
            let scale = containerSize.height / uiImage.size.height
            displayedImageSize = CGSize(
                width: uiImage.size.width * scale * steadyStateZoomScale,
                height: containerSize.height * steadyStateZoomScale
            )
        }
        
        // Calculate maximum allowed offset
        let maxOffsetX = max(0, (displayedImageSize.width - containerSize.width) / 2)
        let maxOffsetY = max(0, (displayedImageSize.height - containerSize.height) / 2)
        
        // Clamp the offset to valid bounds
        steadyStatePanOffset.width = max(-maxOffsetX, min(steadyStatePanOffset.width, maxOffsetX))
        steadyStatePanOffset.height = max(-maxOffsetY, min(steadyStatePanOffset.height, maxOffsetY))
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
