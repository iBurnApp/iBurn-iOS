//
//  EmojiImageRenderer.swift
//  iBurn
//
//  Created by Assistant on 2025-08-09.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import UIKit

/// Renders emoji strings as UIImage for map annotations
final class EmojiImageRenderer {
    
    // MARK: - Properties
    
    static let shared = EmojiImageRenderer()
    
    private let cache = NSCache<NSString, UIImage>()
    
    // MARK: - Configuration
    
    struct Configuration {
        let size: CGSize
        let backgroundColor: UIColor?
        let borderColor: UIColor?
        let borderWidth: CGFloat
        let cornerRadius: CGFloat
        
        static let `default` = Configuration(
            size: CGSize(width: 40, height: 40),
            backgroundColor: nil,
            borderColor: nil,
            borderWidth: 0,
            cornerRadius: 0
        )
        
        static let mapPin = Configuration(
            size: CGSize(width: 36, height: 36),
            backgroundColor: .white,
            borderColor: nil,
            borderWidth: 0,
            cornerRadius: 18
        )
        
        static func mapPinWithStatus(color: UIColor) -> Configuration {
            Configuration(
                size: CGSize(width: 36, height: 36),
                backgroundColor: .white,
                borderColor: color,
                borderWidth: 3,
                cornerRadius: 18
            )
        }
    }
    
    // MARK: - Init
    
    private init() {
        cache.countLimit = 100
    }
    
    // MARK: - Public API
    
    /// Renders an emoji string as a UIImage
    /// - Parameters:
    ///   - emoji: The emoji string to render
    ///   - configuration: Rendering configuration
    /// - Returns: Rendered UIImage or nil if rendering fails
    func renderEmoji(_ emoji: String, configuration: Configuration = .default) -> UIImage? {
        let cacheKey = "\(emoji)_\(configuration.size.width)_\(configuration.size.height)_\(configuration.backgroundColor?.hexString ?? "clear")_\(configuration.borderColor?.hexString ?? "none")_\(configuration.borderWidth)_\(configuration.cornerRadius)" as NSString
        
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        let renderer = UIGraphicsImageRenderer(size: configuration.size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: configuration.size)
            
            // Draw background
            if let backgroundColor = configuration.backgroundColor {
                let path = UIBezierPath(roundedRect: rect.insetBy(dx: configuration.borderWidth / 2, dy: configuration.borderWidth / 2),
                                       cornerRadius: configuration.cornerRadius)
                backgroundColor.setFill()
                path.fill()
            }
            
            // Draw border
            if let borderColor = configuration.borderColor, configuration.borderWidth > 0 {
                let borderPath = UIBezierPath(roundedRect: rect.insetBy(dx: configuration.borderWidth / 2, dy: configuration.borderWidth / 2),
                                             cornerRadius: configuration.cornerRadius)
                borderPath.lineWidth = configuration.borderWidth
                borderColor.setStroke()
                borderPath.stroke()
            }
            
            // Draw emoji
            let fontSize = min(configuration.size.width, configuration.size.height) * 0.6
            let font = UIFont.systemFont(ofSize: fontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font
            ]
            
            let attributedString = NSAttributedString(string: emoji, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: (configuration.size.width - textSize.width) / 2,
                y: (configuration.size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            attributedString.draw(in: textRect)
        }
        
        cache.setObject(image, forKey: cacheKey)
        return image
    }
    
    /// Pre-render commonly used emojis for better performance
    func preloadCommonEmojis() {
        let commonEmojis = [
            "🎨", "⛺", "🎉", "🧑‍🏫", "💃", "🏥", "🔮", "🎯", 
            "🔥", "🔞", "👨‍👩‍👧‍👦", "🎏", "🍔", "🎺", "💗", "🔨", 
            "♻️", "🧘", "🤷"
        ]
        
        for emoji in commonEmojis {
            _ = renderEmoji(emoji, configuration: .mapPin)
            _ = renderEmoji(emoji, configuration: .mapPinWithStatus(color: .systemGreen))
            _ = renderEmoji(emoji, configuration: .mapPinWithStatus(color: .systemOrange))
            _ = renderEmoji(emoji, configuration: .mapPinWithStatus(color: .systemRed))
        }
    }
    
    /// Clear the image cache
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - UIColor Extension

private extension UIColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255) << 0
        return String(format: "#%06x", rgb)
    }
}