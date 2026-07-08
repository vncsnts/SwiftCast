//
//  EditorView.swift
//  SwiftCast
//

import SwiftUI

struct EditorView: View {
    @Environment(\.appTheme) private var t
    @StateObject private var viewModel: EditorViewModel

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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(12)
            }
        }
        // Constrain the canvas to the actual screen clip aspect ratio.
        .aspectRatio(viewModel.screenAspectRatio, contentMode: .fit)
    }

    @ViewBuilder private func cameraClipOverlay(canvasSize: CGSize) -> some View {
        let layout = viewModel.cameraClipLayout
        let clipW = canvasSize.width * layout.frame.width
        let clipH = canvasSize.height * layout.frame.height
        let clipX = canvasSize.width * (layout.frame.origin.x + layout.frame.width / 2)
        let clipY = canvasSize.height * (layout.frame.origin.y + layout.frame.height / 2)

        // Scale camera to fill the clip (maintaining its native AR), then apply user zoom
        // and pan via offset — matching the export compositor's crop+translate approach.
        let cameraAR = viewModel.cameraAspectRatio
        let clipAR = clipW / clipH
        let baseW = cameraAR > clipAR ? clipH * cameraAR : clipW
        let baseH = cameraAR > clipAR ? clipH : clipW / cameraAR
        let scaledW = baseW * layout.zoom
        let scaledH = baseH * layout.zoom
        let panX = (0.5 - layout.focusPoint.x) * max(0, scaledW - clipW)
        let panY = (0.5 - layout.focusPoint.y) * max(0, scaledH - clipH)

        ZStack {
            ZStack {
                VideoClipPlayerView(player: viewModel.cameraPlayer, gravity: .resize)
                    .frame(width: scaledW, height: scaledH)
                    .offset(x: panX, y: panY)
            }
            .frame(width: clipW, height: clipH)
            .clipShape(CameraClipMaskShape(mode: layout.maskMode))

            if viewModel.isInManualFocusMode {
                // Outer glow pulse
                CameraClipMaskShape(mode: layout.maskMode)
                    .stroke(t.color.foreground.accent, lineWidth: 3)
                    .blur(radius: 8)
                    .frame(width: clipW, height: clipH)
                // Crisp border on top of glow
                CameraClipMaskShape(mode: layout.maskMode)
                    .stroke(t.color.foreground.accent.opacity(0.9), lineWidth: 1)
                    .frame(width: clipW, height: clipH)
            }
        }
        .frame(width: clipW, height: clipH)
        // In focus mode use the full clip rectangle so the user can drag all the way
        // to any edge of the frame. In normal mode limit to the visible mask shape
        // so taps in the transparent area fall through to the tap-out layer.
        .contentShape(ClipInteractionShape(maskMode: layout.maskMode, isFocusMode: viewModel.isInManualFocusMode))
        .position(x: clipX, y: clipY)
        .gesture(clipGesture(clipW: clipW, clipH: clipH, canvasSize: canvasSize))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                viewModel.isInManualFocusMode
                    ? viewModel.exitManualFocusMode()
                    : viewModel.enterManualFocusMode()
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(viewModel.isDraggingClip ? t.color.foreground.accent.opacity(0.7) : Color.clear, lineWidth: 1.5)
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
                    Divider().frame(height: 60)
                    focusSection
                    Spacer()
                    actionButtons
                }
                .padding(.horizontal, t.padding.large)
                .padding(.vertical, t.padding.medium)
                .frame(height: 80)
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
        .frame(height: 80)
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
                            .font(.system(size: 16))
                            .frame(width: 30, height: 30)
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
                    .frame(width: 100)
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

    private func clipGesture(clipW: CGFloat, clipH: CGFloat, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if viewModel.isInManualFocusMode {
                    if !viewModel.isFocusDragging { viewModel.beginFocusDrag() }
                    viewModel.updateFocusDrag(
                        translation: value.translation,
                        clipSize: CGSize(width: clipW, height: clipH)
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
