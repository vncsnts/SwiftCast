//
//  EditorView.swift
//  SwiftCast
//

import SwiftUI

struct EditorView: View {
    @Environment(\.appTheme) private var t
    @StateObject private var viewModel: EditorViewModel

    private var style: EditorStyle { EditorStyle.makeStyle(with: t) }

    init(session: RecordingSession) {
        _viewModel = StateObject(wrappedValue: EditorViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            canvas
            Divider()
            toolbar
        }
        .navigationTitle(EditorViewModel.Copy.title)
        .alert(EditorViewModel.Copy.alertTitle, isPresented: $viewModel.isOnAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .alert(EditorViewModel.Copy.exportDoneTitle, isPresented: $viewModel.showExportSuccess) {
            Button("OK") {}
        } message: {
            Text(EditorViewModel.Copy.exportDoneMessage)
        }
    }

    // MARK: - Canvas

    @ViewBuilder private var canvas: some View {
        ZStack {
            // Screen clip fills the entire canvas — no black bars
            if viewModel.session.screenClipURL != nil {
                VideoClipPlayerView(player: viewModel.screenPlayer)
            }

            // Camera clip overlay and playback button use a GeometryReader
            // to get the live canvas size for coordinate calculations.
            GeometryReader { geo in
                // Tap anywhere outside the camera clip to exit focus mode.
                if viewModel.isInManualFocusMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.exitManualFocusMode() }
                }

                if viewModel.session.cameraClipURL != nil {
                    cameraClipOverlay(canvasSize: geo.size)
                }

                // Playback toggle
                Button {
                    viewModel.isPlaying ? viewModel.pauseAll() : viewModel.playAll()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(style.playbackButtonFont)
                        .foregroundColor(style.playbackIconColor)
                        .frame(width: style.playbackButtonDiameter, height: style.playbackButtonDiameter)
                        .background(style.playbackButtonScrim)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(style.playbackButtonPadding)
            }
        }
        // Constrain the canvas to the actual screen clip aspect ratio.
        .aspectRatio(viewModel.screenAspectRatio, contentMode: .fit)
    }

    @ViewBuilder private func cameraClipOverlay(canvasSize: CGSize) -> some View {
        let layout = viewModel.cameraClipLayout
        let geometry = viewModel.cameraClipGeometry(canvasSize: canvasSize)

        ZStack {
            ZStack {
                VideoClipPlayerView(player: viewModel.cameraPlayer, gravity: .resize)
                    .frame(width: geometry.scaledSize.width, height: geometry.scaledSize.height)
                    .offset(x: geometry.panOffset.width, y: geometry.panOffset.height)
            }
            .frame(width: geometry.clipSize.width, height: geometry.clipSize.height)
            .clipShape(CameraClipMaskShape(mode: layout.maskMode))

            if viewModel.isInManualFocusMode {
                // Outer glow pulse
                CameraClipMaskShape(mode: layout.maskMode)
                    .stroke(t.color.foreground.accent, lineWidth: style.focusRingWidth)
                    .blur(radius: style.focusRingGlowRadius)
                    .frame(width: geometry.clipSize.width, height: geometry.clipSize.height)
                // Crisp border on top of glow
                CameraClipMaskShape(mode: layout.maskMode)
                    .stroke(t.color.foreground.accent.opacity(0.9), lineWidth: style.focusHairlineWidth)
                    .frame(width: geometry.clipSize.width, height: geometry.clipSize.height)
            }
        }
        .frame(width: geometry.clipSize.width, height: geometry.clipSize.height)
        // In focus mode use the full clip rectangle so the user can drag all the way
        // to any edge of the frame. In normal mode limit to the visible mask shape
        // so taps in the transparent area fall through to the tap-out layer.
        .contentShape(ClipInteractionShape(maskMode: layout.maskMode, isFocusMode: viewModel.isInManualFocusMode))
        .position(x: geometry.clipCenter.x, y: geometry.clipCenter.y)
        .gesture(clipGesture(clipSize: geometry.clipSize, canvasSize: canvasSize))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                viewModel.isInManualFocusMode
                    ? viewModel.exitManualFocusMode()
                    : viewModel.enterManualFocusMode()
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: style.dragOutlineCornerRadius)
                .stroke(viewModel.isDraggingClip ? t.color.foreground.accent.opacity(0.7) : Color.clear, lineWidth: style.dragOutlineWidth)
        )
    }

    // MARK: - Toolbar

    @ViewBuilder private var toolbar: some View {
        VStack(spacing: 0) {
            if viewModel.isExporting {
                exportProgressBar
            } else {
                HStack(spacing: t.spacing.xl) {
                    maskSection
                    Divider().frame(height: style.toolbarDividerHeight)
                    focusSection
                    Spacer()
                    actionButtons
                }
                .padding(.horizontal, t.padding.large)
                .padding(.vertical, t.padding.medium)
                .frame(height: style.toolbarHeight)
            }
        }
    }

    @ViewBuilder private var exportProgressBar: some View {
        VStack(spacing: t.spacing.small) {
            ProgressView(value: viewModel.exportProgress)
                .progressViewStyle(.linear)
                .padding(.horizontal, t.padding.large)
            Text(EditorViewModel.Copy.exportingLabel)
                .font(t.font.helper)
                .foregroundColor(t.color.foreground.secondary)
        }
        .frame(height: style.toolbarHeight)
        .padding(.horizontal, t.padding.large)
    }

    @ViewBuilder private var maskSection: some View {
        VStack(alignment: .leading, spacing: t.spacing.xs) {
            Text(EditorViewModel.Copy.maskSectionTitle)
                .font(t.font.caption)
                .foregroundColor(t.color.foreground.secondary)
            HStack(spacing: t.spacing.xs) {
                ForEach(CameraClipMask.allCases) { mode in
                    Button {
                        viewModel.setMaskMode(mode)
                    } label: {
                        Image(systemName: mode.systemImage)
                            .font(style.maskIconFont)
                            .frame(width: style.maskIconButtonSize, height: style.maskIconButtonSize)
                            .foregroundColor(viewModel.cameraClipLayout.maskMode == mode
                                             ? t.color.foreground.accent
                                             : t.color.foreground.tertiary)
                            .background(viewModel.cameraClipLayout.maskMode == mode
                                        ? t.color.background.accent.opacity(0.15)
                                        : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: t.cornerRadius.small))
                    }
                    .buttonStyle(.plain)
                    .help(mode.rawValue)
                }
            }
        }
    }

    @ViewBuilder private var focusSection: some View {
        VStack(alignment: .leading, spacing: t.spacing.xs) {
            Text(EditorViewModel.Copy.focusSectionTitle)
                .font(t.font.caption)
                .foregroundColor(t.color.foreground.secondary)
            HStack(spacing: t.spacing.medium) {
                HStack(spacing: t.spacing.xs) {
                    Image(systemName: "minus")
                        .font(t.font.helper)
                        .foregroundColor(t.color.foreground.tertiary)
                    Slider(
                        value: Binding(
                            get: { viewModel.cameraClipLayout.zoom },
                            set: { viewModel.setZoom($0) }
                        ),
                        in: 1.0...4.0,
                        step: 0.1
                    )
                    .frame(width: style.zoomSliderWidth)
                    Image(systemName: "plus")
                        .font(t.font.helper)
                        .foregroundColor(t.color.foreground.tertiary)
                }

                Toggle(isOn: Binding(
                    get: { viewModel.cameraClipLayout.isFaceTrackingEnabled },
                    set: { _ in viewModel.toggleFaceTracking() }
                )) {
                    Label(EditorViewModel.Copy.faceTrackingLabel, systemImage: "face.dashed")
                        .font(t.font.helper)
                        .foregroundColor(t.color.foreground.secondary)
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    @ViewBuilder private var actionButtons: some View {
        VStack(spacing: t.spacing.small) {
            Button(EditorViewModel.Copy.exportButton) {
                viewModel.exportVideo()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isExporting)

            Button(EditorViewModel.Copy.resetButton) {
                viewModel.resetLayout()
            }
            .buttonStyle(.plain)
            .font(t.font.helper)
            .foregroundColor(t.color.foreground.tertiary)
        }
    }

    // MARK: - Gestures

    private func clipGesture(clipSize: CGSize, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if viewModel.isInManualFocusMode {
                    if !viewModel.isFocusDragging { viewModel.beginFocusDrag() }
                    viewModel.updateFocusDrag(
                        translation: value.translation,
                        clipSize: clipSize
                    )
                } else {
                    if !viewModel.isDraggingClip { viewModel.clipDragBegan() }
                    viewModel.clipDragChanged(translation: value.translation, canvasSize: canvasSize)
                }
            }
            .onEnded { _ in
                if viewModel.isInManualFocusMode {
                    viewModel.endFocusDrag()
                } else {
                    viewModel.clipDragEnded()
                }
            }
    }

}

// Switches between the mask shape (normal mode) and a full rectangle (focus mode)
// so focus-adjust drags aren't bounded by the visible mask area.
private struct ClipInteractionShape: Shape {
    let maskMode: CameraClipMask
    let isFocusMode: Bool

    func path(in rect: CGRect) -> Path {
        isFocusMode ? Path(rect) : CameraClipMaskShape(mode: maskMode).path(in: rect)
    }
}
