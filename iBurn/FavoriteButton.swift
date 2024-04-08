//
//  FavoriteButton.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
import SwiftUI

struct FavoriteButton: View {
    @State var isFavorite: Bool
    
    var body: some View {
        Button(action: {
            isFavorite.toggle()
        }, label: {
            Image(isFavorite ? "heart" : "heart.fill")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.red)
                .frame(width: 32, height: 32)
        })
    }
}
