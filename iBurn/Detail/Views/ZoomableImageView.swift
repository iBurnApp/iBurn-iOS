//
//  ZoomableImageView.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/13/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - Public SwiftUI View (Reusable Component)

/// A view that displays a UIImage within a zoomable and pannable scroll view.
///
/// This view is the core component for displaying the interactive image. It should be
/// placed inside a container view that provides chrome, like a close button.
public struct ZoomableImageView: View {
    public let uiImage: UIImage
    
    // Internal state to track zoom level for disabling dismiss gestures
    @State private var isZoomed: Bool = false

    public var body: some View {
        // The underlying representable that wraps UIScrollView
        _ZoomableViewer(uiImage: uiImage, isZoomed: $isZoomed)
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

// MARK: - Internal UIViewRepresentable (Implementation Detail)

fileprivate struct _ZoomableViewer: UIViewRepresentable {
    let uiImage: UIImage
    @Binding var isZoomed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .fast
        
        let imageView = UIImageView(image: uiImage)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        scrollView.addSubview(imageView)
        
        // Store references
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        
        // Set initial frame for image view
        imageView.frame = CGRect(origin: .zero, size: uiImage.size)
        scrollView.contentSize = imageView.frame.size
        
        // Configure double tap
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        
        // Mark that we need initial setup
        context.coordinator.needsInitialSetup = true
        
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Only update if we have valid bounds
        if uiView.bounds.size.width > 0 && uiView.bounds.size.height > 0 {
            context.coordinator.setupZoomScaleIfNeeded()
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        private var parent: _ZoomableViewer
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?
        var needsInitialSetup = true

        init(_ parent: _ZoomableViewer) {
            self.parent = parent
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageIfNeeded()
            
            // Update zoom state asynchronously to avoid SwiftUI update conflicts
            let isCurrentlyZoomed = scrollView.zoomScale > scrollView.minimumZoomScale
            if parent.isZoomed != isCurrentlyZoomed {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.isZoomed = isCurrentlyZoomed
                }
            }
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = self.scrollView,
                  let imageView = self.imageView else { return }
            
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                // Zoom out to fit
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                // Zoom in to 2x at the tapped point
                let tapLocation = gesture.location(in: imageView)
                let zoomScale = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.0)
                let zoomRect = zoomRectForScale(scale: zoomScale, center: tapLocation)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
        
        private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
            guard let scrollView = self.scrollView,
                  let imageView = self.imageView else { return .zero }
            
            var zoomRect = CGRect.zero
            zoomRect.size.height = scrollView.bounds.height / scale
            zoomRect.size.width = scrollView.bounds.width / scale
            
            // Convert center point from image view to scroll view coordinates
            let newCenter = imageView.convert(center, to: scrollView)
            zoomRect.origin.x = newCenter.x - (zoomRect.size.width / 2.0)
            zoomRect.origin.y = newCenter.y - (zoomRect.size.height / 2.0)
            
            return zoomRect
        }
        
        func setupZoomScaleIfNeeded() {
            guard needsInitialSetup,
                  let scrollView = self.scrollView,
                  let imageView = self.imageView,
                  let image = imageView.image,
                  scrollView.bounds.width > 0,
                  scrollView.bounds.height > 0 else { return }
            
            needsInitialSetup = false
            
            let imageSize = image.size
            let scrollViewSize = scrollView.bounds.size
            
            // Calculate scales
            let widthScale = scrollViewSize.width / imageSize.width
            let heightScale = scrollViewSize.height / imageSize.height
            let minScale = min(widthScale, heightScale)
            
            // Configure zoom scales
            scrollView.minimumZoomScale = minScale
            scrollView.maximumZoomScale = max(2.0, minScale * 2.0)
            scrollView.zoomScale = minScale
            
            // Update image view frame to match scaled size
            let scaledImageSize = CGSize(
                width: imageSize.width * minScale,
                height: imageSize.height * minScale
            )
            imageView.frame = CGRect(origin: .zero, size: scaledImageSize)
            
            // Update content size
            scrollView.contentSize = imageView.frame.size
            
            // Center the image
            centerImageIfNeeded()
        }
        
        func centerImageIfNeeded() {
            guard let scrollView = self.scrollView,
                  let imageView = self.imageView else { return }
            
            let scrollViewSize = scrollView.bounds.size
            var frameToCenter = imageView.frame
            
            // Center horizontally
            if frameToCenter.size.width < scrollViewSize.width {
                frameToCenter.origin.x = (scrollViewSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }
            
            // Center vertically
            if frameToCenter.size.height < scrollViewSize.height {
                frameToCenter.origin.y = (scrollViewSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }
            
            imageView.frame = frameToCenter
        }
    }
}