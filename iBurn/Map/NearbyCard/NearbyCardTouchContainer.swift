//
//  NearbyCardTouchContainer.swift
//  iBurn
//
//  Created by Claude Code on 8/7/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Decides, in UIKit, which touches over the nearby card belong to the card.
//
//  The card's hosting view is deliberately held at card size even when the card is
//  collapsed into its pin, because the collapse animation needs somewhere to run — shrink
//  the host and Auto Layout resizes it in one pass, cutting the transition (measured at
//  60fps: card to circle, no frames between). That leaves a card-sized rectangle of empty
//  space over the map whenever the pin is showing, and the map has to stay draggable
//  through it.
//
//  Whether a hosting view already declines touches its SwiftUI content doesn't want is
//  undocumented and version-dependent, and the map being undraggable next to the pin would
//  be an easy regression to ship without noticing. This states the hit region outright
//  instead of inferring it: the container claims only the rectangle the card is drawing in.
//

import UIKit

final class NearbyCardTouchContainer: UIView {

    /// The area the card currently occupies, in this view's coordinate space. Anything
    /// outside it is the map's. Evaluated per touch rather than cached, so it can't go
    /// stale against the card's state.
    var interactiveRect: (() -> CGRect)?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let interactiveRect else { return super.point(inside: point, with: event) }
        return interactiveRect().contains(point)
    }
}
