import SwiftUI
import AppKit // Import AppKit for NSSound

/// A SwiftUI view that displays the camera feed and overlays a ball that follows the detected hand position.
struct CameraGameView: View {
    @ObservedObject var cameraManager: CameraRecordManager
    @EnvironmentObject var soundManager: SoundEffectsManager
    @StateObject private var viewModel: CameraGameViewModel
    
    init(cameraManager: CameraRecordManager) {
        self.cameraManager = cameraManager
        _viewModel = StateObject(wrappedValue: CameraGameViewModel(
            cameraManager: cameraManager,
            soundManager: SoundEffectsManager()
        ))
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Camera feed
                if let frame = cameraManager.frame {
                    Image(decorative: frame, scale: 1.0)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color.black
                }

                // Hand Points Visualization
                if let handPoints = cameraManager.handPoints {
                    ForEach(Array(handPoints.filter { $0.value.confidence > 0.3 }), id: \.key) { point in
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .position(
                                x: (1.0 - point.value.location.x) * geo.size.width,
                                y: (1.0 - point.value.location.y) * geo.size.height
                            )
                    }
                }

                // Falling Circles
                ForEach(viewModel.fallingCircles) { circle in
                    Circle()
                        .fill(circle.color)
                        .frame(width: geo.size.width * circle.radius * 2, height: geo.size.height * circle.radius * 2)
                        .position(
                            x: circle.position.x * geo.size.width,
                            y: circle.position.y * geo.size.height
                        )
                        .scaleEffect(viewModel.popAnimations[circle.id]?.scale ?? 1.0)
                        .opacity(Double(viewModel.popAnimations[circle.id]?.opacity ?? 1.0))
                }
            }
            .onAppear {
                cameraManager.startCapture()
                if viewModel.fallingCircles.isEmpty {
                    viewModel.addFallingCircle()
                }
            }
            .onChange(of: cameraManager.handPosition) { newHand in
                viewModel.updateHandPosition(newHand)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
