//
//  BRCOnboardingViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/15/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import Onboard

@objc class BRCOnboardingViewController: OnboardingViewController {
    private var observer: Any?
    
    fileprivate override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    /** Returns newly configured onboarding view */
    @objc init(completion completionBlock: @escaping () -> ()) {
        let firstPage = OnboardingContentViewController.content(withTitle: "Welcome to iBurn", body: "\nLet's get started!", image: nil, buttonText: "📍 Continue with Location", action: {
            BRCPermissions.promptForLocation({
                print("BRCPermissions promptForLocation")
            })
        })
        firstPage.movesToNextViewController = true
        let secondPage = OnboardingContentViewController.content(withTitle: "Reminders", body: "When you favorite events we can remind you about them later.", image: nil, buttonText: "⏰ Continue with Notifications", action: {
            BRCPermissions.promptForPush({
                print("BRCPermissions promptForPush")
            })
        })
        secondPage.movesToNextViewController = true
        let thirdPage = OnboardingContentViewController.content(withTitle: "Search", body: "Find whatever your heart desires.\n\n\n...especially bacon and coffee.", image: nil, buttonText: nil, action: nil)
        let fourthPage = OnboardingContentViewController.content(withTitle: "Nearby", body: "Quickly find cool new things going on around you.\n\n\n...or just find the closest toilet.", image: nil, buttonText: nil, action: nil)
        let lastPage = OnboardingContentViewController.content(withTitle: "Thank you!", body: "If you enjoy using iBurn, please spread the word.", image: nil, buttonText: "🔥 Ok let's burn!", action: completionBlock)
        let bundle = Bundle.main
        let moviePath = bundle.path(forResource: "onboarding_loop_final", ofType: "mp4")
        let movieURL = URL(fileURLWithPath: moviePath ?? "")
        super.init(backgroundVideoURL: movieURL, contents: [firstPage, secondPage, thirdPage, fourthPage, lastPage])
        shouldFadeTransitions = true
        fadePageControlOnLastPage = true
        stopMoviePlayerWhenDisappear = true
        // If you want to allow skipping the onboarding process, enable skipping and set a block to be executed
        // when the user hits the skip button.
        // onboardingVC.allowSkipping = YES;
        skipHandler = completionBlock
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if observer != nil {
            if let anObserver = observer {
                NotificationCenter.default.removeObserver(anObserver)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // fill frame w/ video
        moviePlayerController.videoGravity = convertToAVLayerVideoGravity(AVLayerVideoGravity.resizeAspectFill.rawValue)
        // loop video http://stackoverflow.com/a/26401680
        weak var weakVC: BRCOnboardingViewController? = self
        // prevent memory cycle
        let noteCenter = NotificationCenter.default
        observer = noteCenter.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue:         // any object can send
            nil, using:         // the queue of the sending
            { note in
                // holding a pointer to avPlayer to reuse it
                weakVC?.moviePlayerController.player?.seek(to: CMTime.zero)
                weakVC?.moviePlayerController.player?.play()
        })
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToAVLayerVideoGravity(_ input: String) -> AVLayerVideoGravity {
	return AVLayerVideoGravity(rawValue: input)
}
