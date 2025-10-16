//
//  HapticsManager.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import SwiftUI
import Combine
import UIKit

@MainActor
final class HapticsManager: ObservableObject {

    // Allow toggling haptics from Settings
    @Published var isEnabled: Bool = true

    // Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGen = UINotificationFeedbackGenerator()
    private let selectionGen = UISelectionFeedbackGenerator()

    init() {
        prepare()
    }

    // Warm up engines to reduce first-call latency
    func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGen.prepare()
        selectionGen.prepare()
    }

    // MARK: - Impact

    func light() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    func medium() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    func heavy() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
    }

    /// Fine-grained impact (0.0...1.0). Falls back to medium if outside range.
    func impact(intensity: CGFloat) {
        guard isEnabled else { return }
        let clamped = max(0.0, min(1.0, intensity))
        if clamped == 0.0 || clamped == 1.0 {
            impactMedium.impactOccurred()
        } else {
            impactMedium.impactOccurred(intensity: clamped)
        }
    }

    // MARK: - Notifications

    func success() {
        guard isEnabled else { return }
        notificationGen.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        notificationGen.notificationOccurred(.warning)
    }

    func error() {
        guard isEnabled else { return }
        notificationGen.notificationOccurred(.error)
    }

    // MARK: - Selection

    func selectionChanged() {
        guard isEnabled else { return }
        selectionGen.selectionChanged()
    }
}
