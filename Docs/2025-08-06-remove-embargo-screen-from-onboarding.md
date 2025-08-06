# Remove Embargo Screen from Onboarding Flow

## Date: 2025-08-06

## Problem Statement
The location unlock/embargo screen appearing immediately after onboarding was confusing for users. It presented a passcode entry screen that created friction and uncertainty about data availability.

## Solution Overview
Replaced the full embargo screen presentation with a simple informational alert that explains when location data will be available, maintaining transparency while reducing user confusion.

## Key Changes

### 1. Modified Onboarding Completion Flow
**File**: `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/BRCAppDelegate.m`
**Method**: `setupNormalRootViewController` (lines 414-437)

#### Previous Implementation:
- After onboarding, immediately presented `EmbargoPasscodeView` if data was embargoed
- Required user interaction with passcode field or skip button
- Modal full-screen presentation blocked access to app

#### New Implementation:
- Shows simple `UIAlertController` with informational message
- Single "OK" button for easy dismissal
- Non-blocking - users can immediately access the app

### Alert Content
```objc
Title: "Location Data Coming Soon"
Message: "Camp location data is restricted until one week before gates open, 
         and art location data is restricted until the event starts. 
         This is due to an embargo imposed by the Burning Man organization.
         
         The app will automatically unlock itself after gates open at 
         12:01am Sunday and you're on playa."
Button: "OK"
```

## Technical Details

### Code Change
Replaced embargo screen presentation logic with alert:

```objc
// Show informational alert about embargo if needed
if (![BRCEmbargo allowEmbargoedData]) {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"Location Data Coming Soon" 
        message:@"Camp location data is restricted..." 
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction 
        actionWithTitle:@"OK" 
        style:UIAlertActionStyleDefault 
        handler:nil];
    
    [alert addAction:okAction];
    [self.tabBarController presentViewController:alert animated:YES completion:nil];
}
```

## Expected Outcomes

### User Experience Improvements:
1. **Reduced Friction**: Users no longer face a complex passcode screen after onboarding
2. **Clear Communication**: Alert explains data restrictions without requiring action
3. **Immediate Access**: Users can dismiss alert and explore the app immediately
4. **Preserved Functionality**: Manual unlock still available in More tab for those with passcode

### Unchanged Functionality:
- Automatic unlock still occurs when gates open
- Region-based unlock continues to work
- Manual passcode entry remains available in More tab
- Data embargo logic unchanged

## Testing Performed
- Built project successfully with `xcodebuild`
- No compilation errors
- Alert presentation logic verified

## Related Files
- `EmbargoPasscodeView.swift` - Still used for manual unlock in More tab
- `EmbargoPasscodeViewModel.swift` - Embargo logic unchanged
- `BRCEmbargo.m` - Core embargo functionality preserved
- `MoreViewController.swift` - Manual unlock option remains

## Notes
- This change only affects the post-onboarding flow
- Users who have already completed onboarding won't see any change
- The embargo system itself remains fully functional
- Consider monitoring user feedback to ensure the alert provides sufficient information