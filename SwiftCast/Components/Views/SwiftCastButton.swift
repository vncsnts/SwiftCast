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
/// countdown with hover-to-cancel; the countdown state machine lives in
/// SwiftCastButtonViewModel — this view only renders.
struct SwiftCastButton: View {
    @Environment(\.appTheme) private var t
    var action: (() -> Void)?
    var cancelAction: (() -> Void)?
    var title: String
    var systemImage: String?
    var tint: Color?
    var isProminent = true
    var withCountdown = false
    @StateObject private var viewModel = SwiftCastButtonViewModel()

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                if isProminent || viewModel.isCancel {
                    coreButton
                        .buttonStyle(.glassProminent)
                } else {
                    coreButton
                        .buttonStyle(.glass)
                }
            } else if isProminent || viewModel.isCancel {
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
            viewModel.hoverChanged(hovered)
        })
        .animation(.easeInOut, value: viewModel.onCountdown)
        .animation(.easeInOut, value: viewModel.isCancel)
    }

    private var coreButton: some View {
        Button {
            viewModel.didTap(withCountdown: withCountdown, action: action, cancelAction: cancelAction)
        } label: {
            HStack(spacing: t.spacing.small) {
                if let symbol = viewModel.currentSymbol(base: systemImage) {
                    Image(systemName: symbol)
                }
                Text(viewModel.currentTitle(base: title))
                    .contentTransition(.numericText())
            }
            .font(t.font.button)
            .frame(maxWidth: .infinity)
            .animation(.default, value: viewModel.currentCount)
        }
    }

    private var currentTint: Color? {
        if viewModel.isCancel { return t.color.status.recording }
        guard isProminent else { return nil }
        return tint ?? t.color.background.accent
    }
}

struct SwiftCastButton_Previews: PreviewProvider {
    static var previews: some View {
        SwiftCastButton(title: "SwiftCast")
    }
}
