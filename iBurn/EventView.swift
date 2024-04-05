//
//  BRCEventObjectTableView.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
import SwiftUI



struct EventView: View {
    @ObservedObject var viewModel: EventViewModel
    
    var body: some View {
        EmptyView()
            .onAppear {
                Task(priority: .userInitiated) { [weak viewModel] in
                    await viewModel?.appear()
                }
            }
    }
}

