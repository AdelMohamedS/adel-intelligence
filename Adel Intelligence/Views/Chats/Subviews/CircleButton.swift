//
//  CircleButton.swift
//  Adel Intelligence
//
//  Created by Adel on 8/8/24.
//

import SwiftUI

public struct CircleButton: View {
    private let systemImage: String
    private let action: () -> Void
    
    public init(systemImage: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(.foreground)
                .fontWeight(.bold)
                .padding(8)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityInputLabels([accessibilityLabel])
        .background(.background)
        .buttonStyle(.borderless)
        .clipShape(.circle)
        .colorInvert()
    }

    private var accessibilityLabel: String {
        switch systemImage {
        case "xmark", "xmark.circle", "xmark.circle.fill": return "Close"
        case "chevron.left": return "Back"
        case "chevron.right": return "Next"
        default: return systemImage.replacingOccurrences(of: ".", with: " ")
        }
    }
}
