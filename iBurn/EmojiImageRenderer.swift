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
        let statusDotColor: UIColor?
        let statusDotSize: CGFloat
        let isFavorite: Bool
        let heartSize: CGFloat
        let visitStatus: Int
        let visitEmojiSize: CGFloat
        
        init(size: CGSize, 
             backgroundColor: UIColor? = nil,
             borderColor: UIColor? = nil,
             borderWidth: CGFloat = 0,
             cornerRadius: CGFloat = 0,
             statusDotColor: UIColor? = nil,
             statusDotSize: CGFloat = 8,
             isFavorite: Bool = false,
             heartSize: CGFloat = 10,
             visitStatus: Int = 0,
             visitEmojiSize: CGFloat = 10) {
            self.size = size
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.borderWidth = borderWidth
            self.cornerRadius = cornerRadius
            self.statusDotColor = statusDotColor
            self.statusDotSize = statusDotSize
            self.isFavorite = isFavorite
            self.heartSize = heartSize
            self.visitStatus = visitStatus
            self.visitEmojiSize = visitEmojiSize
        }
        
        static let `default` = Configuration(
            size: CGSize(width: 40, height: 40)
        )
        
        static let mapPin = Configuration(
            size: CGSize(width: 36, height: 36)
        )
        
        static func mapPinWithStatus(color: UIColor? = nil, isFavorite: Bool = false, visitStatus: Int = 0) -> Configuration {
            Configuration(
                size: CGSize(width: 36, height: 36),
                statusDotColor: color,
                statusDotSize: 10,
                isFavorite: isFavorite,
                heartSize: 10,
                visitStatus: visitStatus,
                visitEmojiSize: 10
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
        let cacheKey = "\(emoji)_\(configuration.size.width)_\(configuration.size.height)_\(configuration.backgroundColor?.hexString ?? "clear")_\(configuration.borderColor?.hexString ?? "none")_\(configuration.borderWidth)_\(configuration.cornerRadius)_\(configuration.statusDotColor?.hexString ?? "none")_\(configuration.statusDotSize)_\(configuration.isFavorite)_\(configuration.heartSize)_\(configuration.visitStatus)_\(configuration.visitEmojiSize)" as NSString
        
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
            let fontSize = min(configuration.size.width, configuration.size.height) * 0.7
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
            
            // Draw status dot if present
            if let statusDotColor = configuration.statusDotColor {
                let dotRadius = configuration.statusDotSize / 2
                let dotOffset: CGFloat = 2
                let dotCenter = CGPoint(x: dotOffset + dotRadius, y: dotOffset + dotRadius)
                
                // Draw white background for the dot for better visibility
                let whiteDotPath = UIBezierPath(arcCenter: dotCenter, 
                                               radius: dotRadius + 1, 
                                               startAngle: 0, 
                                               endAngle: .pi * 2, 
                                               clockwise: true)
                UIColor.white.setFill()
                whiteDotPath.fill()
                
                // Draw the colored dot
                let dotPath = UIBezierPath(arcCenter: dotCenter, 
                                          radius: dotRadius, 
                                          startAngle: 0, 
                                          endAngle: .pi * 2, 
                                          clockwise: true)
                statusDotColor.setFill()
                dotPath.fill()
            }
            
            // Draw heart emoji if favorite
            if configuration.isFavorite {
                let heartEmoji = "❤️"
                let heartOffset: CGFloat = 1
                
                // Position heart in bottom-right corner
                let heartSize = configuration.heartSize
                let heartRect = CGRect(
                    x: configuration.size.width - heartSize - heartOffset,
                    y: configuration.size.height - heartSize - heartOffset,
                    width: heartSize,
                    height: heartSize
                )
                
                // Create attributes with white stroke for visibility
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                
                let fontSize = heartSize * 0.85
                let font = UIFont.systemFont(ofSize: fontSize)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .strokeColor: UIColor.white,
                    .strokeWidth: -4.0,  // Negative for stroke + fill
                    .foregroundColor: UIColor.systemPink,
                    .paragraphStyle: paragraphStyle
                ]
                
                // Draw the emoji heart
                let attributedString = NSAttributedString(string: heartEmoji, attributes: attributes)
                let textSize = attributedString.size()
                let centeredRect = CGRect(
                    x: heartRect.origin.x + (heartRect.width - textSize.width) / 2,
                    y: heartRect.origin.y + (heartRect.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                attributedString.draw(in: centeredRect)
            }
            
            // Draw visit status emoji if visited or want to visit
            if configuration.visitStatus != 0 {
                let visitEmoji: String
                let emojiColor: UIColor
                
                switch configuration.visitStatus {
                case 1: // visited
                    visitEmoji = "✅"
                    emojiColor = UIColor.systemGreen
                case 2: // wantToVisit
                    visitEmoji = "⭐"
                    emojiColor = UIColor.systemYellow
                default:
                    visitEmoji = ""
                    emojiColor = UIColor.clear
                }
                
                if !visitEmoji.isEmpty {
                    let visitOffset: CGFloat = 1
                    
                    // Position visit emoji in top-right corner
                    let visitSize = configuration.visitEmojiSize
                    let visitRect = CGRect(
                        x: configuration.size.width - visitSize - visitOffset,
                        y: visitOffset,
                        width: visitSize,
                        height: visitSize
                    )
                    
                    // Create attributes with white stroke for visibility
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center
                    
                    let fontSize = visitSize * 0.85
                    let font = UIFont.systemFont(ofSize: fontSize)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .strokeColor: UIColor.white,
                        .strokeWidth: -4.0,  // Negative for stroke + fill
                        .foregroundColor: emojiColor,
                        .paragraphStyle: paragraphStyle
                    ]
                    
                    // Draw the visit emoji
                    let attributedString = NSAttributedString(string: visitEmoji, attributes: attributes)
                    let textSize = attributedString.size()
                    let centeredRect = CGRect(
                        x: visitRect.origin.x + (visitRect.width - textSize.width) / 2,
                        y: visitRect.origin.y + (visitRect.height - textSize.height) / 2,
                        width: textSize.width,
                        height: textSize.height
                    )
                    attributedString.draw(in: centeredRect)
                }
            }
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
            _ = renderEmoji(emoji, configuration: .mapPinWithStatus(isFavorite: true))
            _ = renderEmoji(emoji, configuration: .mapPinWithStatus(color: .systemGreen, isFavorite: true))
            
            // Preload visit status combinations
            _ = renderEmoji(emoji, configuration: .mapPinWithStatus(visitStatus: 1)) // visited
            _ = renderEmoji(emoji, configuration: .mapPinWithStatus(visitStatus: 2)) // want to visit
            _ = renderEmoji(emoji, configuration: .mapPinWithStatus(isFavorite: true, visitStatus: 1))
            _ = renderEmoji(emoji, configuration: .mapPinWithStatus(isFavorite: true, visitStatus: 2))
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