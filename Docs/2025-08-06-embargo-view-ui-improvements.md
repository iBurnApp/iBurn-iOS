# Embargo View UI Improvements

## Date: 2025-08-06

## Overview
Enhanced the EmbargoPasscodeView UI with two key improvements:
1. Added a system-style close (X) button overlay in the top right corner
2. Added a toggle to show/hide the passcode entry field with playful text

## Changes Made

### 1. Close Button Overlay
**File Modified:** `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/EmbargoPasscodeView.swift`

Added a close button overlay to the ScrollView using SwiftUI's `.overlay` modifier:
- Positioned in top-right corner with `.topTrailing` alignment
- Uses SF Symbol "xmark.circle.fill" for standard iOS appearance
- Styled with white X on semi-transparent black background
- Calls the existing `dismissAction` when tapped
- Provides better UX alongside the existing Skip button

### 2. Toggle for Passcode Entry
**Files Modified:**
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/EmbargoPasscodeViewModel.swift`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/EmbargoPasscodeView.swift`

Added a toggle control to show/hide the passcode entry:
- New `@Published` property `showPasscodeEntry` in view model
- Toggle with text "I am super special and am allowed early access"
- Conditionally displays the passcode SecureField and Unlock button
- Maintains consistent styling with the rest of the view

## Technical Implementation

### Close Button Code
```swift
.overlay(alignment: .topTrailing) {
    Button(action: {
        viewModel.dismissAction?()
    }) {
        Image(systemName: "xmark.circle.fill")
            .font(.largeTitle)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .black.opacity(0.6))
            .clipShape(Circle())
    }
    .padding()
}
```

### Toggle Implementation
```swift
Toggle("I am super special and am allowed early access", isOn: $viewModel.showPasscodeEntry)
    .toggleStyle(SwitchToggleStyle(tint: Color(colors.primaryColor)))
    .foregroundColor(.black)
    .padding(.horizontal)

if viewModel.showPasscodeEntry {
    // Existing HStack with passcode field and unlock button
}
```

## Context
The embargo view is presented as a full-screen modal from the More tab when users tap on "Unlock Location Data". This view explains the data embargo imposed by Burning Man organization and allows users with special access to enter a passcode to unlock location data early.

## Build Status
✅ Build successful - No compilation errors

## Related Work
- Previous commit removed the embargo screen from the onboarding flow
- Embargo screen now only accessible through More tab for manual unlock