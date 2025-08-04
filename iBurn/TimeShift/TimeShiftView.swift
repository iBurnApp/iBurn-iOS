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
                    onLocationSelected: viewModel.updateLocation
                )
                .frame(maxHeight: selectedDetent == .large ? .infinity : 200)
                
                Divider()
                
                // Time Controls Section
                ScrollView {
                    VStack(spacing: 20) {
                        // Reset to Reality button - prominent at top
                        if !viewModel.isAtCurrentReality {
                            Button(action: {
                                withAnimation {
                                    viewModel.resetToReality()
                                }
                            }) {
                                Label("Reset to Reality", systemImage: "location.north.line.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(Appearance.currentColors.primaryColor))
                        }
                        
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
                        
                        // Location Section
                        VStack(spacing: 8) {
                            Text("Tap the map to warp to a new location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            
                            LocationComparisonView(
                                realLocation: viewModel.currentRealLocation,
                                warpedLocation: viewModel.selectedLocation
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Warp Travel")
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
        VStack(spacing: 12) {
            // Time comparison
            VStack(spacing: 6) {
                Text("Time Warp")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Now")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDate(Date.present))
                            .font(.system(.callout, design: .rounded))
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Warped")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDate(viewModel.selectedDate))
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
                
                if let offsetDesc = viewModel.timeOffsetDescription {
                    Text(offsetDesc)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
    
    private var quickActionButtons: some View {
        HStack(spacing: 10) {
                Button(action: { 
                    viewModel.resetToNow()
                }) {
                    Label("Now", systemImage: "clock")
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Reset to current time")
                
                Button(action: { 
                    viewModel.setToSunrise()
                }) {
                    Image(systemName: "sunrise")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Sunrise")
                .accessibilityHint("Set time to 7:00 AM")
                
                Button(action: {
                    viewModel.setToNoon()
                }) {
                    Image(systemName: "sun.max")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Noon")
                .accessibilityHint("Set time to 12:00 PM")
                
                Button(action: {
                    viewModel.setToSunset()
                }) {
                    Image(systemName: "sunset")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Sunset")
                .accessibilityHint("Set time to 7:00 PM")
        }
    }
}

// MARK: - LocationComparisonView

struct LocationComparisonView: View {
    let realLocation: CLLocation?
    let warpedLocation: CLLocation?
    
    @State private var realAddress: String = "Loading..."
    @State private var warpedAddress: String = "No location selected"
    @State private var isLoadingReal = true
    @State private var isLoadingWarped = false
    
    var distance: String {
        guard let real = realLocation, let warped = warpedLocation else { return "" }
        let meters = real.distance(from: warped)
        if meters < 1000 {
            return String(format: "%.0f meters apart", meters)
        } else {
            return String(format: "%.1f km apart", meters / 1000)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Location Warp")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
            
            // Real Location
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Current Location")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    if isLoadingReal {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                Text(realAddress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let location = realLocation {
                    Text(String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Arrow and Distance
            HStack {
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                
                if !distance.isEmpty {
                    Text(distance)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            // Warped Location
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Warped Location")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    if isLoadingWarped {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                Text(warpedAddress)
                    .font(.caption2)
                    .foregroundColor(warpedLocation != nil ? .secondary : .secondary.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                
                if let location = warpedLocation {
                    Text(String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .onAppear {
            geocodeLocations()
        }
        .onChange(of: realLocation?.coordinate.latitude) { _ in
            geocodeLocations()
        }
        .onChange(of: warpedLocation?.coordinate.latitude) { _ in
            geocodeLocations()
        }
    }
    
    private func geocodeLocations() {
        // Geocode real location
        if let real = realLocation {
            isLoadingReal = true
            PlayaGeocoder.shared.asyncReverseLookup(real.coordinate) { address in
                DispatchQueue.main.async {
                    self.isLoadingReal = false
                    self.realAddress = address ?? "Unknown location"
                }
            }
        } else {
            realAddress = "Location unavailable"
            isLoadingReal = false
        }
        
        // Geocode warped location
        if let warped = warpedLocation {
            isLoadingWarped = true
            PlayaGeocoder.shared.asyncReverseLookup(warped.coordinate) { address in
                DispatchQueue.main.async {
                    self.isLoadingWarped = false
                    self.warpedAddress = address ?? "Unknown location"
                }
            }
        } else {
            warpedAddress = "Tap the map to select"
            isLoadingWarped = false
        }
    }
}

// MARK: - LocationAddressView (keeping for backwards compatibility)

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