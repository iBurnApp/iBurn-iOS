import SwiftUI
import Combine

class EmbargoPasscodeViewModel: ObservableObject {
    @Published var passcode: String = ""
    @Published var countdownString: String = ""
    @Published var isDataUnlocked: Bool = false
    @Published var shouldShowUnlockError: Bool = false
    @Published var showingSocialWebView: Bool = false
    @Published var socialURLToOpen: URL? = nil
    @Published var showPasscodeEntry: Bool = false
    
    private var countdownTimer: Timer?
    private let festivalStartDate: Date = BRCEventObject.festivalStartDate()
    
    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
        self.isDataUnlocked = checkDataUnlocked()
        if !isDataUnlocked {
            startCountdownTimer()
        } else {
             countdownString = "Location Data Unlocked!"
        }
    }
    
    deinit {
        countdownTimer?.invalidate()
    }
    
    private func checkDataUnlocked() -> Bool {
        let now = Date.present
        let timeLeftInterval = now.timeIntervalSince(festivalStartDate)
        return timeLeftInterval >= 0 || UserDefaults.enteredEmbargoPasscode
    }
    
    func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshCountdownLabel()
        }
        countdownTimer?.fire()
    }
    
    func refreshCountdownLabel() {
        if checkDataUnlocked() {
            isDataUnlocked = true
            countdownString = "Location Data Unlocked!"
            countdownTimer?.invalidate()
            return
        }
        
        let now = Date.present
        let unitFlags: Set<Calendar.Component> = [.day, .hour, .minute, .second]
        let components = Calendar.current.dateComponents(unitFlags, from: now, to: festivalStartDate)
        
        var parts: [String] = []
        
        let day = components.day ?? 0
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        if day > 0 {
            parts.append("\(day) day\(day == 1 ? "" : "s")")
        }
        
        if hour > 0 || day > 0 {
             parts.append("\(hour) hour\(hour == 1 ? "" : "s")")
        }
        
        if minute > 0 || hour > 0 || day > 0 {
             parts.append("\(minute) minute\(minute == 1 ? "" : "s")")
        }
        
        if let second = components.second {
            if !parts.isEmpty || second >= 0 {
                 parts.append("\(second) second\(second == 1 ? "" : "s")")
            }
        }

        if parts.isEmpty && festivalStartDate.timeIntervalSince(now) > 0 {
            countdownString = "0 seconds"
            return
        } else if parts.isEmpty && festivalStartDate.timeIntervalSince(now) <= 0 {
            countdownString = "Location Data Unlocked!"
            return
        }
        
        countdownString = parts.joined(separator: "\n")
    }
    
    func unlockButtonPressed() {
        if BRCEmbargo.isEmbargoPasscodeString(passcode) {
            UserDefaults.enteredEmbargoPasscode = true
            isDataUnlocked = true
            countdownTimer?.invalidate()
        } else {
            shouldShowUnlockError = true
        }
    }
    
    func skipButtonPressed() {
        dismissAction?()
    }

    func openSocialLink(_ url: URL, from viewController: UIViewController) {
        WebViewHelper.presentWebView(url: url, from: viewController)
    }

    func handleAlreadyUnlocked() {
        if isDataUnlocked {
            dismissAction?()
        }
    }
}
