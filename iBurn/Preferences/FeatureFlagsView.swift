//
//  FeatureFlagsView.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

#if DEBUG

import SwiftUI

/// Debug view for toggling feature flags at runtime
struct FeatureFlagsView: View {
    
    @State private var mockDateEnabled = UserDefaults.standard.bool(forKey: "BRCMockDateEnabled")
    @State private var mockDateValue = Date()
    @State private var currentDate = Date.present
    @State private var timer: Timer?
    
    // Dynamically calculated Burning Man dates based on Labor Day
    private var eventYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    private var laborDay: Date {
        // Labor Day is the first Monday of September
        var components = DateComponents()
        components.year = eventYear
        components.month = 9
        components.weekday = 2 // Monday
        components.weekdayOrdinal = 1 // First Monday
        components.hour = 18 // Gates close at 6pm
        components.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private var gatesOpen: Date {
        // Event starts 9 days before Labor Day (Sunday of the week before)
        Calendar.current.date(byAdding: .day, value: -8, to: laborDay) ?? Date()
    }
    
    private var earlyBurn: Date {
        // Wednesday of the first week
        Calendar.current.date(byAdding: .day, value: -6, to: laborDay) ?? Date()
    }
    
    private var midBurn: Date {
        // Friday of the first week
        Calendar.current.date(byAdding: .day, value: -4, to: laborDay) ?? Date()
    }
    
    private var templeBurn: Date {
        // Sunday night before Labor Day
        let date = Calendar.current.date(byAdding: .day, value: -1, to: laborDay) ?? Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 20 // Temple burn at 8pm
        components.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return Calendar.current.date(from: components) ?? date
    }
    
    private var gatesClose: Date {
        laborDay // Gates close on Labor Day
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        List {
            // Date Override Section
            Section {
                Toggle("Override Current Date", isOn: $mockDateEnabled)
                    .onChange(of: mockDateEnabled) { newValue in
                        updateMockDate(enabled: newValue)
                    }
                
                HStack {
                    Text("Current Date:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(dateFormatter.string(from: currentDate))
                        .font(.system(.body, design: .monospaced))
                }
                
                if mockDateEnabled {
                    DatePicker("Override Date", 
                              selection: $mockDateValue,
                              in: createDateRange(),
                              displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: mockDateValue) { newValue in
                            NSDate.brc_setOverrideDate(newValue)
                            UserDefaults.standard.set(newValue, forKey: "BRCMockDateValue")
                            updateCurrentDate()
                        }
                }
            } header: {
                Text("Date Override")
            } footer: {
                Text("Override the current date for testing time-sensitive features like event status colors.")
                    .font(.footnote)
            }
            
            // Quick Presets Section
            if mockDateEnabled {
                Section {
                    Button("Gates Open - \(formatPresetDate(gatesOpen))") {
                        setPresetDate(gatesOpen)
                    }
                    Button("Early Burn - \(formatPresetDate(earlyBurn))") {
                        setPresetDate(earlyBurn)
                    }
                    Button("Mid Burn - \(formatPresetDate(midBurn))") {
                        setPresetDate(midBurn)
                    }
                    Button("Temple Burn - \(formatPresetDate(templeBurn))") {
                        setPresetDate(templeBurn)
                    }
                    Button("Gates Close - \(formatPresetDate(gatesClose))") {
                        setPresetDate(gatesClose)
                    }
                } header: {
                    Text("Quick Presets")
                } footer: {
                    Text("Common test dates for Burning Man \(eventYear)")
                        .font(.footnote)
                }
            }
            
            // Info Section
            Section {
                Text("Feature flags are only available in DEBUG builds and control experimental features during development.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupView()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func setupView() {
        // Load saved date if available
        if let savedDate = UserDefaults.standard.object(forKey: "BRCMockDateValue") as? Date {
            mockDateValue = savedDate
        } else {
            // Default to mid-burn if no date saved
            mockDateValue = midBurn
        }
        
        updateCurrentDate()
        
        // Update current date display every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateCurrentDate()
        }
    }
    
    private func updateCurrentDate() {
        currentDate = Date.present
    }
    
    private func updateMockDate(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "BRCMockDateEnabled")
        if enabled {
            NSDate.brc_setOverrideDate(mockDateValue)
        } else {
            NSDate.brc_clearOverrideDate()
        }
        updateCurrentDate()
    }
    
    private func setPresetDate(_ date: Date) {
        mockDateValue = date
        NSDate.brc_setOverrideDate(date)
        UserDefaults.standard.set(date, forKey: "BRCMockDateValue")
        updateCurrentDate()
    }
    
    private func createDateRange() -> ClosedRange<Date> {
        // Allow testing from 2 weeks before to 1 week after the event
        let start = Calendar.current.date(byAdding: .day, value: -14, to: gatesOpen) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: gatesClose) ?? Date()
        return start...end
    }
    
    private func formatPresetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct FeatureFlagsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FeatureFlagsView()
        }
    }
}

#endif
