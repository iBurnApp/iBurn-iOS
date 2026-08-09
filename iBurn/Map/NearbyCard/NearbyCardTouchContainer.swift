//
//  NearbyCardTouchContainer.swift
//  iBurn
//
//  Created by Claude Code on 8/7/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Decides, in UIKit, which touches over the nearby card belong to the card.
//
//  The card fades in and out and its host resizes a beat behind, so there are moments when
//  the hosting view covers map the card isn't drawing on. Whether a hosting view already
//  declines touches its SwiftUI content doesn't want is undocumented and version-dependent,
//  and a patch of undraggable map would be an easy regression to ship without noticing.
//  This states the hit region outright instead of inferring it: the container claims only
//  the rectangle the card is drawing in.
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
