//
//  DayPicker.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/1/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import UIKit
import Anchorage

/// i give up

public final class DayView: UIView {
    
    public var didSelect: ((Date)->Void)?
    
    public var date: Date? {
        didSet {
            guard let date = self.date else { return }
            let df = DayView.df
            let weekday = df.shortWeekdaySymbols[Calendar.current.component(.weekday, from: date)]
            let number = Calendar.current.component(.day, from: date)
            let index = weekday.index(weekday.startIndex, offsetBy: 3)
            let title = String(weekday[...index]).uppercased()
            self.titleLabel.text = title
            self.numberLabel.text = "\(number)"
        }
    }

    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    
    private static let df = DateFormatter()
    
    @IBAction func buttonPressed(_ sender: Any) {
        guard let date = self.date else { return }
        didSelect?(date)
    }
    
    public static func fromNib() -> DayView? {
        let bundle = Bundle(for: self)
        let nib = UINib(nibName: "DayView", bundle: bundle)
        return nib.instantiate(withOwner: self, options: nil).first as? DayView
    }
}

public final class WeekView: UIView {
    
    public var startDate: Date? {
        didSet {
            guard let startDate = self.startDate else { return }
            let days: [Date] = (0..<7).compactMap {
                var day = DateComponents()
                day.day = $0
                let date = Calendar.current.date(byAdding: day, to: startDate)
                return date
            }
            self.dayViews = days.compactMap {
                let dayView = DayView.fromNib()
                dayView?.date = $0
                return dayView
            }
        }
    }
    
    private let stackView = UIStackView()
    private var dayViews: [DayView] = []
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        self.startDate = Date.now()
    }
}

public final class DayPicker: UIView {
    
    
    
    private let stackView = UIStackView()
    private let scrollView = UIScrollView()

    
    required public override init(frame: CGRect) {
        
        super.init(frame: frame)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
