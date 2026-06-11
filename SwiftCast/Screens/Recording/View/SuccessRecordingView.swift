//
//  SuccessRecordingView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 8/8/23.
//

import SwiftUI

struct SuccessRecordingView: View {
    @Environment(\.appTheme) private var t
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel = SuccessRecordingViewModel()
    @State var screenUrl: String
    @State var cameraUrl: String

    var body: some View {
        VStack(spacing: t.spacing.large) {
            Image(systemName: "checkmark.circle.fill")
                .font(t.font.iconLarge)
                .foregroundColor(t.color.status.success)

            VStack(spacing: t.spacing.xs) {
                Text(SuccessRecordingViewModel.Copy.title)
                    .font(t.font.heading)
                    .foregroundColor(t.color.foreground.default)
                Text(SuccessRecordingViewModel.Copy.subtitle)
                    .font(t.font.body)
                    .foregroundColor(t.color.foreground.secondary)
            }

            if !screenUrl.isEmpty || !cameraUrl.isEmpty {
                VStack(spacing: 0) {
                    if !screenUrl.isEmpty {
                        linkRow(systemImage: "display", label: SuccessRecordingViewModel.Copy.screenLinkLabel, url: screenUrl)
                    }
                    if !screenUrl.isEmpty && !cameraUrl.isEmpty {
                        Rectangle()
                            .fill(t.color.border.default)
                            .frame(height: 1)
                            .padding(.leading, t.padding.medium + 20 + t.padding.medium)
                    }
                    if !cameraUrl.isEmpty {
                        linkRow(systemImage: "video.fill", label: SuccessRecordingViewModel.Copy.cameraLinkLabel, url: cameraUrl)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: t.cornerRadius.medium, style: .continuous))
                .glassCard(cornerRadius: t.cornerRadius.medium)
            }

            SwiftCastButton(action: {
                dismiss()
            }, title: SuccessRecordingViewModel.Copy.doneButtonTitle)
        }
        .padding(t.padding.xl)
        .frame(width: 340)
    }

    @ViewBuilder private func linkRow(systemImage: String, label: String, url: String) -> some View {
        HStack(spacing: t.spacing.medium) {
            Image(systemName: systemImage)
                .font(t.font.body)
                .foregroundColor(t.color.foreground.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(t.font.helper)
                    .foregroundColor(t.color.foreground.secondary)
                Text(url)
                    .font(t.font.body)
                    .foregroundColor(t.color.foreground.default)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: t.spacing.small)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(t.font.body)
                    .foregroundColor(t.color.foreground.secondary)
            }
            .buttonStyle(.plain)
            .help(SuccessRecordingViewModel.Copy.copyLinkHelp)
        }
        .padding(t.padding.medium)
    }
}
