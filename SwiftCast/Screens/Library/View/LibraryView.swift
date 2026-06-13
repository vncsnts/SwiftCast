//
//  LibraryView.swift
//  SwiftCast
//

import SwiftUI

struct LibraryView: View {
    @Environment(\.appTheme) private var t
    @StateObject private var viewModel = LibraryViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .navigationTitle(LibraryViewModel.Copy.title)
        .alert(LibraryViewModel.Copy.alertTitle, isPresented: $viewModel.isOnAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .onAppear {
            viewModel.loadSessions()
        }
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: t.spacing.medium) {
            Image(systemName: "film.stack")
                .font(t.font.iconLarge)
                .foregroundColor(t.color.foreground.tertiary)
            Text(LibraryViewModel.Copy.emptyTitle)
                .font(t.font.pillValue)
                .foregroundColor(t.color.foreground.default)
            Text(LibraryViewModel.Copy.emptySubtitle)
                .font(t.font.helper)
                .foregroundColor(t.color.foreground.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, t.padding.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: t.spacing.medium) {
                ForEach(viewModel.sessions) { session in
                    NavigationLink(value: session) {
                        SessionRowView(session: session)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteSession(session)
                        } label: {
                            Label(LibraryViewModel.Copy.deleteLabel, systemImage: "trash")
                        }
                    }
                }
            }
            .padding(t.padding.large)
        }
    }
}

// MARK: - Session Row

private struct SessionRowView: View {
    @Environment(\.appTheme) private var t
    let session: RecordingSession

    var body: some View {
        HStack(spacing: t.spacing.medium) {
            Image(systemName: "film.stack")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(t.color.foreground.accent)
                .frame(width: 48, height: 48)
                .background(t.color.background.card)
                .clipShape(RoundedRectangle(cornerRadius: t.cornerRadius.small))

            VStack(alignment: .leading, spacing: t.spacing.xs) {
                Text(session.displayTitle)
                    .font(t.font.body)
                    .foregroundColor(t.color.foreground.default)
                HStack(spacing: t.spacing.xs) {
                    if session.screenClipURL != nil {
                        badge(LibraryViewModel.Copy.screenClipBadge)
                    }
                    if session.cameraClipURL != nil {
                        badge(LibraryViewModel.Copy.cameraClipBadge)
                    }
                    if session.exportedVideoURL != nil {
                        badge(LibraryViewModel.Copy.exportedBadge, accent: true)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(t.font.helper)
                .foregroundColor(t.color.foreground.tertiary)
        }
        .padding(t.padding.medium)
        .background(t.color.background.card)
        .clipShape(RoundedRectangle(cornerRadius: t.cornerRadius.medium, style: .continuous))
    }

    @ViewBuilder private func badge(_ text: String, accent: Bool = false) -> some View {
        Text(text)
            .font(t.font.hotkey)
            .foregroundColor(accent ? t.color.foreground.accent : t.color.foreground.secondary)
            .padding(.horizontal, t.padding.small)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: t.cornerRadius.small)
                    .fill(accent ? t.color.background.accent.opacity(0.15) : t.color.background.card)
            )
    }
}
