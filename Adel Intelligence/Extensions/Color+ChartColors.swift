//
//  Color+ChartColors.swift
//  Adel Intelligence
//
//  Created by Adel The Adroit  on 01/05/2025.
//

import SwiftUI

extension Color {
    static let chartColors: [Color] = [
        .blue,
        .green,
        .orange,
        .purple,
        .red,
        .pink,
        .yellow,
        .black
    ]

    static func forModel(_ model: String) -> Color {
        switch model {
        case "ChatGPT":
            return .black
        case "Microsoft Copilot":
            return .purple
        case "Google Gemini":
            return .blue
        default:
            let hash = abs(model.hashValue % chartColors.count)
            return chartColors[hash]
        }
    }
}
