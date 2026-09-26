//
//  UIViewConstraintsTests.swift
//  iBurnTests
//
//  The PureLayout replacements in `UIView+Constraints.swift`.
//

import UIKit
import XCTest
@testable import iBurn

@MainActor
final class UIViewConstraintsTests: XCTestCase {

    func testPinEdgesFillsSuperview() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let child = UIView()
        container.addSubview(child)

        let constraints = child.pinEdgesToSuperview()
        container.layoutIfNeeded()

        XCTAssertEqual(constraints.count, 4)
        XCTAssertFalse(child.translatesAutoresizingMaskIntoConstraints)
        XCTAssertEqual(child.frame, container.bounds)
    }

    func testPinEdgesAppliesInsetsInward() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let child = UIView()
        container.addSubview(child)

        child.pinEdgesToSuperview(insets: UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))
        container.layoutIfNeeded()

        XCTAssertEqual(child.frame, CGRect(x: 2, y: 1, width: 194, height: 96))
    }

    func testCenterXInSuperview() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let child = UIView()
        container.addSubview(child)

        let constraint = child.centerXInSuperview()
        NSLayoutConstraint.activate([
            child.widthAnchor.constraint(equalToConstant: 50),
            child.heightAnchor.constraint(equalToConstant: 10),
            child.topAnchor.constraint(equalTo: container.topAnchor),
        ])
        container.layoutIfNeeded()

        XCTAssertNotNil(constraint)
        XCTAssertFalse(child.translatesAutoresizingMaskIntoConstraints)
        XCTAssertEqual(child.center.x, 100)
    }
}
