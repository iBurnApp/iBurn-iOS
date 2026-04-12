//
//  ChatView.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import SwiftUI
import PlayaDB
import UIKit

@available(iOS 26, *)
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.themeColors) var themeColors
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if viewModel.messages.isEmpty {
                            quickStartSection
                        }

                        ForEach(viewModel.messages) { message in
                            ChatBubble(
                                message: message,
                                viewModel: viewModel,
                                onNavigate: navigateToDetail
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 8) {
                TextField("Ask about Burning Man...", text: $viewModel.inputText)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit { viewModel.send() }
                    .disabled(viewModel.isProcessing)

                Button {
                    viewModel.send()
                } label: {
                    Image(systemName: viewModel.isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.inputText.isEmpty && !viewModel.isProcessing ? .gray : themeColors.detailColor)
                }
                .disabled(viewModel.inputText.isEmpty && !viewModel.isProcessing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("AI Guide")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Quick Start

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .center, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(themeColors.detailColor)

                Text("Your AI Playa Guide")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeColors.primaryColor)

                Text("Ask me anything about Burning Man, or try a quick action below.")
                    .font(.subheadline)
                    .foregroundColor(themeColors.secondaryColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                ForEach(QuickAction.quickStartActions) { action in
                    QuickStartCard(action: action, themeColors: themeColors) {
                        viewModel.executeQuickAction(action)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Navigation

    private func navigateToDetail(uid: String) {
        guard let resolved = viewModel.resolvedObjects[uid] else { return }
        let playaDB = viewModel.playaDB
        let detailVC: UIViewController
        switch resolved {
        case .art(let art):
            detailVC = DetailViewControllerFactory.create(with: art, playaDB: playaDB)
        case .camp(let camp):
            detailVC = DetailViewControllerFactory.create(with: camp, playaDB: playaDB)
        case .event(let event):
            detailVC = DetailViewControllerFactory.create(with: event, playaDB: playaDB)
        case .mutantVehicle(let mv):
            detailVC = DetailViewControllerFactory.create(with: mv, playaDB: playaDB)
        }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let navController = window.rootViewController?.findNavigationController() else {
            return
        }
        navController.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Quick Start Card

@available(iOS 26, *)
struct QuickStartCard: View {
    let action: QuickAction
    let themeColors: ImageColors
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 22))
                    .foregroundColor(themeColors.detailColor)
                Text(action.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(themeColors.primaryColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeColors.detailColor.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

#endif
