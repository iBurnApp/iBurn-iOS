import SwiftUI
import SafariServices

struct EmbargoPasscodeView: View {
    @ObservedObject var viewModel: EmbargoPasscodeViewModel

    var body: some View {
        let colors = Appearance.currentColors
        
        ScrollView {
            VStack(spacing: 20) {
                Text(viewModel.countdownString)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .font(.title)
                    .padding(.top)

                if !viewModel.isDataUnlocked {
                    Text("Camp location data is restricted until one week before gates open, and art location data is restricted until the event starts. This is due to an embargo imposed by the Burning Man organization. \n\nThe app will automatically unlock itself after gates open at 12:01am Sunday and you're on playa. \n\nWe will post the passcode publicly after gates open. Please do not ask us for the passcode, thanks!")
                        .font(.body)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    socialButtonsView(colors: colors)
                        .padding(.top, 10)

                    SecureField("Passcode", text: $viewModel.passcode)
                        .textFieldStyle(.roundedBorder)
                        .padding(10)
                        .textContentType(.password)
                        .foregroundColor(.black)
                        .modifier(ShakeEffect(shakes: viewModel.shouldShowUnlockError ? 3 : 0))
                        .animation(viewModel.shouldShowUnlockError ? .default : nil, value: viewModel.shouldShowUnlockError)
                        .onChange(of: viewModel.shouldShowUnlockError) { newValue in
                            if newValue {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    viewModel.shouldShowUnlockError = false
                                }
                            }
                        }
                    
                    HStack {
                        Button("Skip") {
                            viewModel.skipButtonPressed()
                        }
                        .buttonStyle(.bordered)
                        .accentColor(Color(colors.secondaryColor))

                        Spacer()

                        Button("Unlock") {
                            viewModel.unlockButtonPressed()
                        }
                        .font(.body.bold())
                        .buttonStyle(.borderedProminent)
                        .accentColor(Color(colors.primaryColor))
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .padding(.horizontal)
        }
        .background(
            Image("PlayaBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .overlay(
                    Color(colors.backgroundColor)
                        .opacity(0.15)
                )
                .ignoresSafeArea()
        )
        .preferredColorScheme(.light)
        .onAppear {
            viewModel.handleAlreadyUnlocked()
        }
        .onChange(of: viewModel.isDataUnlocked) { newIsDataUnlockedValue in
            if newIsDataUnlockedValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.dismissAction?()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSocialWebView) {
            if let url = viewModel.socialURLToOpen {
                SafariView(url: url)
                    .onDisappear {
                        self.viewModel.socialURLToOpen = nil
                    }
            }
        }
    }

    @ViewBuilder
    private func socialButtonsView(colors: BRCImageColors) -> some View {
        // UPDATED: Social links and button style
        let socialLinks: [(name: String, urlString: String)] = [
            (name: "Facebook", urlString: "https://facebook.com/iBurnApp"),
            (name: "GitHub", urlString: "https://github.com/iBurnApp/iBurn-iOS")
        ]

        HStack(spacing: 20) { // Adjusted spacing for text buttons
            ForEach(socialLinks, id: \.urlString) { link in
                if let url = URL(string: link.urlString) {
                    Button(action: {
                        // Fallback to web URL for all links now
                        self.viewModel.socialURLToOpen = url
                        self.viewModel.showingSocialWebView = true
                    }) {
                        Text(link.name)
                    }
                    .buttonStyle(.bordered)
                    .accentColor(Color(colors.secondaryColor))
                    .accessibilityLabel(link.name)
                }
            }
        }
    }
}

// Helper for SFSafariViewController - remains the same
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        // config.entersReaderIfAvailable = true // Optional: enable reader mode
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = Appearance.currentColors.primaryColor // Match app's tint color
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        // No update needed
    }
}

// Shake effect for TextField - remains the same
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    init(shakes: Int) {
        self.animatableData = CGFloat(shakes)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * shakesPerUnit),
            y: 0))
    }
}

@objc public final class EmbargoPasscodeFactory: NSObject {
    @objc public static func makeViewController(dismissAction: (() -> Void)? = nil) -> UIViewController {
        EmbargoPasscodeHostingViewController(dismissAction: dismissAction)
    }
}

class EmbargoPasscodeHostingViewController: UIHostingController<EmbargoPasscodeView> {
    private let viewModel: EmbargoPasscodeViewModel

    @objc init(dismissAction: (() -> Void)? = nil) {
        self.viewModel = EmbargoPasscodeViewModel(dismissAction: dismissAction)
        let rootView = EmbargoPasscodeView(viewModel: self.viewModel)
        super.init(rootView: rootView)
        // Ensure the dismissAction is properly set on the viewModel instance held by this controller
        self.viewModel.dismissAction = dismissAction
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Match the background color to avoid flashes during presentation
        self.view.backgroundColor = Appearance.currentColors.backgroundColor
        overrideUserInterfaceStyle = .light
    }
}

#Preview {
    let viewModel = EmbargoPasscodeViewModel(dismissAction: nil)
    return EmbargoPasscodeView(viewModel: viewModel)
}
