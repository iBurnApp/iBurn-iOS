//
//  ImageAnnotationView.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/12/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import PureLayout

final class ImageAnnotationView: MLNAnnotationView {
    
    // MARK: Properties
    
    static let reuseIdentifier = "BRCAnnotationView"
    
    var image: UIImage? {
        didSet {
            let imageFrame: CGRect
            if let image = self.image {
                imageFrame = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            } else {
                imageFrame = .zero
            }
            imageView.image = image
            imageView.frame = imageFrame
            frame = imageFrame
        }
    }
    
    private let imageView = UIImageView()
    
    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Overrides
    
    override func prepareForReuse() {
        imageView.image = nil
        if dragState != .none {
            endDragging()
        }
    }
    
    override func setDragState(_ dragState: MLNAnnotationViewDragState, animated: Bool) {
        super.setDragState(dragState, animated: animated)
        switch dragState {
        case .starting:
            startDragging()
        case .dragging:
            break
        case .ending, .canceling:
            endDragging()
        case .none:
            break
        @unknown default:
            break
        }
    }
    
    func addLongPressGesture(target: Any?, action: Selector, minimumPressDuration: TimeInterval = 0.5) {
        guard gestureRecognizers?.first(where: { $0 is UILongPressGestureRecognizer }) == nil else {
            return
        }
        
        let longPressGesture = UILongPressGestureRecognizer(target: target, action: action)
        longPressGesture.minimumPressDuration = minimumPressDuration
        longPressGesture.cancelsTouchesInView = false
        longPressGesture.delaysTouchesBegan = false
        addGestureRecognizer(longPressGesture)
    }
}

extension ImageAnnotationView {
    func hapticFeedback() {
        // Give the user more haptic feedback when they drop the annotation.
        if #available(iOS 10.0, *) {
            let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
            hapticFeedback.impactOccurred()
        }
    }
    
    // When the user interacts with an annotation, animate opacity and scale changes.
    func startDragging() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0, options: [], animations: {
            self.layer.opacity = 0.8
            self.transform = CGAffineTransform.identity.scaledBy(x: 1.5, y: 1.5)
        }, completion: nil)
        
        hapticFeedback()
    }
    
    func endDragging() {
        transform = CGAffineTransform.identity.scaledBy(x: 1.5, y: 1.5)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0, options: [], animations: {
            self.layer.opacity = 1
            self.transform = CGAffineTransform.identity.scaledBy(x: 1, y: 1)
        }, completion: nil)
        
        hapticFeedback()
    }
}

private extension ImageAnnotationView {
    func commonInit() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        imageView.autoPinEdgesToSuperviewEdges()
    }
}
