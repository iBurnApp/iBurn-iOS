//
//  ShareQRCodeView.swift
//  iBurn
//
//  Created by iBurn Development Team on 8/8/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct ShareQRCodeView: View {
    let title: String
    let locationText: String?
    let shareURL: URL
    let themeColors: BRCImageColors
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var qrCodeImage: UIImage?
    
    // Convenience init for BRCDataObject
    init(dataObject: BRCDataObject, themeColors: BRCImageColors? = nil) {
        self.title = dataObject.title
        self.locationText = dataObject.playaLocation
        self.shareURL = dataObject.generateShareURL() ?? URL(string: "https://iburnapp.com")!
        self.themeColors = themeColors ?? BRCImageColors.colors(for: dataObject, fallback: Appearance.currentColors)
    }
    
    // New init for BRCMapPoint
    init(mapPoint: BRCMapPoint) {
        self.title = mapPoint.title ?? "Custom Map Pin"
        self.locationText = nil // Map points don't have playa location text
        self.shareURL = mapPoint.generateShareURL() ?? URL(string: "https://iburnapp.com")!
        self.themeColors = Appearance.currentColors
    }
    
    private var accentColor: Color {
        // Use the theme's primary color
        Color(themeColors.primaryColor)
    }
    
    private var backgroundColor: Color {
        Color(themeColors.backgroundColor)
    }
    
    private var secondaryTextColor: Color {
        Color(themeColors.secondaryColor)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Title and description
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if let location = locationText, !location.isEmpty {
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(secondaryTextColor)
                    } else if locationText == nil {
                        // For map points, show "Custom Map Pin" subtitle
                        Text("Custom Map Pin")
                            .font(.subheadline)
                            .foregroundColor(secondaryTextColor)
                    }
                }
                .padding(.horizontal)
                
                // QR Code
                ZStack {
                    if let qrCodeImage = qrCodeImage {
                        Image(uiImage: qrCodeImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 250, height: 250)
                            .overlay(
                                ProgressView()
                            )
                    }
                    
                    // iBurn logo in center of QR code (optional, comment out if not wanted)
                    // Uncomment below if you have an AppIcon image asset
                    /*
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    */
                }
                
                // AirDrop hint
                Label {
                    Text("You can AirDrop this link to nearby friends")
                        .font(.footnote)
                } icon: {
                    Image(systemName: "wifi")
                        .font(.footnote)
                }
                .foregroundColor(secondaryTextColor)
                .padding(.horizontal)
                
                Spacer()
                
                // Share button
                Button(action: shareContent) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top)
            .background(backgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
        .onAppear {
            generateQRCode()
        }
    }
    
    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        // Convert URL to data
        let data = shareURL.absoluteString.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        // Set error correction level to high for logo overlay
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else { return }
        
        // Scale the image to make it larger
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        // Convert to UIImage
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            qrCodeImage = UIImage(cgImage: cgImage)
        }
    }
    
    private func shareContent() {
        // Share only the URL
        let activityItems: [Any] = [shareURL]
        
        // Add custom "Open in Safari" activity
        let customActivities = [OpenInSafariActivity()]
        
        let activityController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: customActivities
        )
        
        // iPad support
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.height - 100, width: 0, height: 0)
            }
            
            // Find the presented view controller to present from
            var presentingVC = rootViewController
            while let presented = presentingVC.presentedViewController {
                presentingVC = presented
            }
            
            presentingVC.present(activityController, animated: true)
        }
    }
}

// MARK: - Hosting Controller

class ShareQRCodeHostingController: UIHostingController<ShareQRCodeView> {
    // Init for BRCDataObject
    init(dataObject: BRCDataObject, themeColors: BRCImageColors? = nil) {
        let colors = themeColors ?? BRCImageColors.colors(for: dataObject, fallback: Appearance.currentColors)
        let shareView = ShareQRCodeView(dataObject: dataObject, themeColors: colors)
        super.init(rootView: shareView)
        
        setupModal()
    }
    
    // Init for BRCMapPoint
    init(mapPoint: BRCMapPoint) {
        let shareView = ShareQRCodeView(mapPoint: mapPoint)
        super.init(rootView: shareView)
        
        setupModal()
    }
    
    private func setupModal() {
        // Set modal presentation style
        self.modalPresentationStyle = .pageSheet
        
        if let sheet = self.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Preview

struct ShareQRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock data object for preview
        let mockObject = BRCArtObject()
        
        return ShareQRCodeView(dataObject: mockObject ?? BRCArtObject())
    }
}