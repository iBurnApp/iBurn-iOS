import SwiftUI
import SafariServices

struct EmbargoPasscodeView: View {
    @ObservedObject var viewModel: EmbargoPasscodeViewModel

    var body: some View {
        let colors = Appearance.currentColors
        
        ScrollView {
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 20)
                Text(viewModel.countdownString)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .font(.title)
                    .padding(.top)

                if !viewModel.isDataUnlocked {
                    Text("Camp location data is restricted until one week before gates open, and art location data is restricted until the event starts. This is due to an embargo imposed by the Burning Man organization. \n\nDon't worry, the app will automatically unlock itself after gates open at 12:01am Sunday and you're on playa.")
                        .font(.body)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Toggle("I am super special and am allowed early access", isOn: $viewModel.showPasscodeEntry)
                        .toggleStyle(SwitchToggleStyle(tint: Color(colors.primaryColor)))
                        .foregroundColor(.black)
                        .padding(.horizontal)
                    
                    if viewModel.showPasscodeEntry {
                        HStack {
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
            }
            .padding(.vertical)
            .padding(.horizontal)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: {
                viewModel.dismissAction?()
            }) {
                // Close Button
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding()
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
