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
import CoreLocation
import PlayaGeocoder

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
                            VStack(spacing: 8) {
                                Text("Tap the map to select a new location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let location = viewModel.selectedLocation {
                                    LocationAddressView(location: location)
                                }
                            }
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

// MARK: - LocationAddressView

struct LocationAddressView: View {
    let location: CLLocation
    @State private var address: String = "Loading address..."
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text(address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Spacer()
            }
            
            HStack {
                Text("Coordinates:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
        .onAppear {
            geocodeLocation()
        }
        .onChange(of: location.coordinate.latitude) { _ in
            geocodeLocation()
        }
        .onChange(of: location.coordinate.longitude) { _ in
            geocodeLocation()
        }
    }
    
    private func geocodeLocation() {
        isLoading = true
        address = "Loading address..."
        
        PlayaGeocoder.shared.asyncReverseLookup(location.coordinate) { locationString in
            DispatchQueue.main.async {
                self.isLoading = false
                if let locationString = locationString, !locationString.isEmpty {
                    self.address = locationString
                } else {
                    self.address = "Address not found"
                }
            }
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