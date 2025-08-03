//
//  TimeShiftView.swift
//  iBurn
//
//  Created by Claude Code on 8/3/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import MapLibre
import Foundation

public struct TimeShiftView: View {
    @ObservedObject var viewModel: TimeShiftViewModel
    @State private var selectedDetent: PresentationDetent = .medium
    
    public init(viewModel: TimeShiftViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Map Section
                TimeShiftMapView(
                    selectedLocation: $viewModel.selectedLocation,
                    isLocationOverrideEnabled: $viewModel.isLocationOverrideEnabled,
                    onLocationSelected: viewModel.updateLocation
                )
                .frame(maxHeight: selectedDetent == .large ? .infinity : 200)
                .overlay(alignment: .topTrailing) {
                    if viewModel.isLocationOverrideEnabled {
                        Button("Reset Location") {
                            withAnimation {
                                viewModel.isLocationOverrideEnabled = false
                                viewModel.selectedLocation = nil
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
                
                Divider()
                
                // Time Controls Section
                ScrollView {
                    VStack(spacing: 20) {
                        // Current Selection Display
                        timeSelectionDisplay
                        
                        // Date Picker
                        DatePicker(
                            "Select Time",
                            selection: $viewModel.selectedDate,
                            in: YearSettings.eventStart...YearSettings.eventEnd,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        
                        // Quick Actions
                        quickActionButtons
                        
                        // Location Override Toggle
                        Toggle("Override Location", isOn: $viewModel.isLocationOverrideEnabled)
                            .padding(.horizontal)
                        
                        if viewModel.isLocationOverrideEnabled {
                            Text("Tap the map to select a new location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Time Travel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.cancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        viewModel.apply()
                    }
                    .disabled(!viewModel.hasUnsavedChanges)
                    .fontWeight(viewModel.hasUnsavedChanges ? .semibold : .regular)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var timeSelectionDisplay: some View {
        VStack(spacing: 8) {
            if let offsetDesc = viewModel.timeOffsetDescription {
                Label(offsetDesc, systemImage: "clock")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text(viewModel.dateRangeDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var quickActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { 
                viewModel.resetToNow()
            }) {
                Label("Now", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            
            Button(action: { 
                viewModel.addOneDay()
            }) {
                Label("+1 Day", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.bordered)
            
            Button(action: {
                viewModel.setToSunset()
            }) {
                Label("Sunset", systemImage: "sunset")
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct TimeShiftView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = TimeShiftViewModel()
        TimeShiftView(viewModel: viewModel)
    }
}
#endif