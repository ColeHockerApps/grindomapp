//
//  Theme.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    @Published var theme: AppTheme = .dark
    @Published var colors: ThemeColors = ThemeColors.dark
    @Published var metrics: ThemeMetrics = ThemeMetrics.default

    func toggleTheme() {
        theme = (theme == .dark) ? .light : .dark
        colors = (theme == .dark) ? .dark : .light
    }
}

enum AppTheme: String, Codable {
    case light
    case dark
}

struct ThemeColors {
    // MARK: - Core palette
    let background: Color
    let surface: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color

    // MARK: - Status colors
    let statusNew: Color
    let statusInProgress: Color
    let statusDone: Color
    let statusCanceled: Color

    // MARK: - Accessor
    func forStatus(_ status: OrderStatus) -> Color {
        switch status {
        case .new: return statusNew
        case .inProgress: return statusInProgress
        case .done: return statusDone
        case .canceled: return statusCanceled
        }
    }

    // MARK: - Presets
    static let dark = ThemeColors(
        background: Color(red: 0.07, green: 0.07, blue: 0.09),
        surface: Color(red: 0.13, green: 0.13, blue: 0.16),
        textPrimary: .white,
        textSecondary: .white.opacity(0.7),
        accent: Color(red: 0.35, green: 0.55, blue: 1.0),
        statusNew: .blue,
        statusInProgress: .yellow,
        statusDone: .green,
        statusCanceled: .gray
    )

    static let light = ThemeColors(
        background: Color(red: 0.97, green: 0.97, blue: 0.99),
        surface: .white,
        textPrimary: .black,
        textSecondary: .black.opacity(0.6),
        accent: Color(red: 0.25, green: 0.45, blue: 0.95),
        statusNew: .blue,
        statusInProgress: .orange,
        statusDone: .green,
        statusCanceled: .gray
    )
}

struct ThemeMetrics {
    let spacingXS: CGFloat = 4
    let spacingS: CGFloat = 8
    let spacing: CGFloat = 12
    let spacingL: CGFloat = 16
    let spacingXL: CGFloat = 24
    let cornerRadius: CGFloat = 14
    let columnWidth: CGFloat = 320

    static let `default` = ThemeMetrics()
}

// MARK: - Icon helper

struct ThemeIcons {
    static func forStatus(_ status: OrderStatus) -> String {
        switch status {
        case .new: return "sparkles"
        case .inProgress: return "hourglass"
        case .done: return "checkmark.seal.fill"
        case .canceled: return "xmark.octagon.fill"
        }
    }
}
