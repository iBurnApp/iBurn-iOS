//
//  UIView+Constraints.swift
//  iBurn
//
//  The two PureLayout conveniences the app used, rebuilt on NSLayoutAnchor.
//

import UIKit

extension UIView {

    /// Pins leading, trailing, top and bottom to the superview's edges.
    ///
    /// Like PureLayout's `autoPinEdgesToSuperviewEdges(with:)`, this turns off
    /// `translatesAutoresizingMaskIntoConstraints`, and the insets push inward on every side.
    @discardableResult
    func pinEdgesToSuperview(insets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        guard let superview else {
            assertionFailure("pinEdgesToSuperview() needs a superview")
            return []
        }
        translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: superview.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -insets.bottom),
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints
    }

    /// Centers horizontally in the superview, like PureLayout's
    /// `autoAlignAxis(toSuperviewAxis: .vertical)`.
    @discardableResult
    func centerXInSuperview() -> NSLayoutConstraint? {
        guard let superview else {
            assertionFailure("centerXInSuperview() needs a superview")
            return nil
        }
        translatesAutoresizingMaskIntoConstraints = false
        let constraint = centerXAnchor.constraint(equalTo: superview.centerXAnchor)
        constraint.isActive = true
        return constraint
    }
}
