//
//  SwiftCastButton.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import SwiftUI

/// Primary Liquid Glass button. Prominent style fills with the accent
/// (or a custom tint, e.g. statusRecording while recording); the
/// non-prominent style is clear glass. Supports the 3-second start
/// countdown with hover-to-cancel.
struct SwiftCastButton: View {
    @Environment(\.appTheme) private var t
    var action: (() -> Void)?
    var cancelAction: (() -> Void)?
    var title: String
    var systemImage: String?
    var tint: Color?
    var isProminent = true
    var withCountdown = false
    @State private var onCountdown = false
    @State private var currentCount = 3
    @State private var isCancel = false

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                if isProminent || isCancel {
                    coreButton
                        .buttonStyle(.glassProminent)
                } else {
                    coreButton
                        .buttonStyle(.glass)
                }
            } else if isProminent || isCancel {
                coreButton
                    .buttonStyle(.borderedProminent)
            } else {
                coreButton
                    .buttonStyle(.bordered)
            }
        }
        .tint(currentTint)
        .primaryControlSize()
        .onHover(perform: { hovered in
            if hovered && onCountdown {
                isCancel = true
            } else {
                isCancel = false
            }
        })
        .animation(.easeInOut, value: onCountdown)
        .animation(.easeInOut, value: isCancel)
    }

    private var coreButton: some View {
        Button {
            if withCountdown {
                if isCancel {
                    isCancel = false
                    onCountdown = false
                    currentCount = 3
                    onCountdown = false
                    cancelAction?()
                } else {
                    onCountdown = true
                    Task {
                        repeat {
                            currentCount -= 1
                            try? await Task.sleep(nanoseconds: 1000000000)
                            if currentCount == 0 {
                                onCountdown = false
                                currentCount = 3
                                action?()
                            }
                        } while onCountdown
                    }
                }

            } else {
                action?()
            }
        } label: {
            HStack(spacing: t.spacing.small) {
                if let symbol = currentSymbol {
                    Image(systemName: symbol)
                }
                Text(currentTitle)
                    .contentTransition(.numericText())
            }
            .font(t.font.button)
            .frame(maxWidth: .infinity)
            .animation(.default, value: currentCount)
        }
    }

    private var currentTitle: String {
        if isCancel { return "Cancel" }
        if onCountdown { return "Starting in \(currentCount + 1)" }
        return title
    }

    private var currentSymbol: String? {
        if isCancel { return "xmark" }
        if onCountdown { return "timer" }
        return systemImage
    }

    private var currentTint: Color? {
        if isCancel { return t.color.status.recording }
        guard isProminent else { return nil }
        return tint ?? t.color.background.accent
    }
}

struct SwiftCastButton_Previews: PreviewProvider {
    static var previews: some View {
        SwiftCastButton(title: "SwiftCast")
    }
}
