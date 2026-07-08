//
//  SwiftCastButtonViewModel.swift
//  SwiftCast
//

import Foundation

/// Owns SwiftCastButton's countdown state machine (start countdown, hover-to-cancel,
/// fire on zero) so the view stays a dumb renderer.
@MainActor
final class SwiftCastButtonViewModel: ObservableObject {
    @Published private(set) var onCountdown = false
    @Published private(set) var currentCount = 3
    @Published private(set) var isCancel = false

    private static let countdownSeconds = 3

    func hoverChanged(_ hovered: Bool) {
        isCancel = hovered && onCountdown
    }

    /// Handles a tap: without a countdown the action fires immediately; with one, the
    /// first tap starts the countdown and a hover-tap cancels it.
    func didTap(withCountdown: Bool, action: (() -> Void)?, cancelAction: (() -> Void)?) {
        guard withCountdown else {
            action?()
            return
        }
        if isCancel {
            isCancel = false
            onCountdown = false
            currentCount = Self.countdownSeconds
            cancelAction?()
        } else {
            onCountdown = true
            Task { [weak self] in
                guard let self else { return }
                repeat {
                    currentCount -= 1
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if currentCount == 0 {
                        onCountdown = false
                        currentCount = Self.countdownSeconds
                        action?()
                    }
                } while onCountdown
            }
        }
    }

    func currentTitle(base: String) -> String {
        if isCancel { return Copy.cancelTitle }
        if onCountdown { return Copy.startingTitle(currentCount + 1) }
        return base
    }

    func currentSymbol(base: String?) -> String? {
        if isCancel { return "xmark" }
        if onCountdown { return "timer" }
        return base
    }
}

extension SwiftCastButtonViewModel {
    enum Copy {
        static let cancelTitle = "Cancel"
        static func startingTitle(_ count: Int) -> String { "Starting in \(count)" }
    }
}
