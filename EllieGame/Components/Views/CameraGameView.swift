import SwiftUI
import AppKit // Import AppKit for NSSound

/// A SwiftUI view that displays the camera feed and overlays a ball that follows the detected hand position.
struct CameraGameView: View {
    @ObservedObject var cameraManager: CameraRecordManager
    @State private var lastHandPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    let ballRadius: CGFloat = 0.08 // 8% of width/height for visibility

    // MARK: Game State
    @State private var fallingCircles: [FallingCircle] = []
    // private let fallingCircleTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect() // Timer to create new circles more frequently
    private let gameLoopTimer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect() // Timer for game updates (falling, collision)

    // MARK: - Drawing
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

                // Hand-controlled Ball
                Circle()
                    .fill(Color.green)
                    .frame(width: geo.size.width * ballRadius * 2, height: geo.size.height * ballRadius * 2)
                    .position(
                        x: lastHandPosition.x * geo.size.width,
                        y: lastHandPosition.y * geo.size.height
                    )
                    .onAppear {
                        print("Hand-controlled ball should appear at: \(lastHandPosition), geo: \(geo.size)")
                    }

                // Falling Circles
                ForEach(fallingCircles) { circle in
                    Circle()
                    .fill(circle.color)
                    .frame(width: geo.size.width * circle.radius * 2, height: geo.size.height * circle.radius * 2)
                    .position(
                        x: circle.position.x * geo.size.width,
                        y: circle.position.y * geo.size.height
                    )
                }
            }
            .onAppear {
                print("CameraGameView appeared, geo: \(geo.size)")
                cameraManager.startCapture()
                // Ensure a circle is present when the game starts
                if fallingCircles.isEmpty {
                    addFallingCircle(in: geo.size)
                }
            }
            .onChange(of: cameraManager.handPosition) { newHand in
                print("Hand position changed (unflipped): \(String(describing: newHand))")
                if let hand = newHand {
                    // Flip the hand position horizontally to match the flipped preview
                    let flippedHand = CGPoint(x: 1.0 - hand.x, y: hand.y)
                    print("Hand position (flipped): \(flippedHand))")
                    withAnimation(.easeOut(duration: 0.1)) {
                        lastHandPosition = flippedHand
                    }
                }
            }
            // Removed: .onReceive(fallingCircleTimer) { _ in addFallingCircle(in: geo.size) }
            .onReceive(gameLoopTimer) { _ in
                updateGame(in: geo.size)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    // MARK: - Game Logic

    /// Updates the positions of falling circles and checks for collisions.
    private func updateGame(in size: CGSize) {
        // Debug print for game loop frequency
        print("updateGame called. Falling circles count: \(fallingCircles.count).")

        // Update falling circles' positions
        for index in fallingCircles.indices {
            fallingCircles[index].position.y += fallingCircles[index].speed
        }

        // Remove circles that fall off the bottom
        fallingCircles.removeAll { $0.position.y > (1.0 + $0.radius) }
        
        // --- Collision Detection --- //
        // Create a list of indices to remove
        var indicesToRemove: [Int] = []
        let handBallCenter = lastHandPosition
        let handBallRadius = ballRadius // Use the same radius as defined for the ball

        for index in fallingCircles.indices {
            let circle = fallingCircles[index]
            
            // Calculate the distance between the center of the hand ball and the falling circle
            let dx = handBallCenter.x - circle.position.x
            let dy = handBallCenter.y - circle.position.y
            let distanceSquared = dx * dx + dy * dy
            
            // Calculate the sum of the radii squared
            let combinedRadii = handBallRadius + circle.radius
            let combinedRadiiSquared = combinedRadii * combinedRadii
            
            // Check for collision (distance less than sum of radii)
            if distanceSquared < combinedRadiiSquared {
                indicesToRemove.append(index)
                print("Circle caught! Removing circle at \(circle.position).")
                // Add a new circle immediately when one is caught
                addFallingCircle(in: size)

                NSSound(named: "Pop")?.play()
            }
        }
        
        // Remove circles in reverse order to avoid index issues
        for index in indicesToRemove.reversed() {
            fallingCircles.remove(at: index)
        }
        
        // Ensure there's always at least one circle if the array becomes empty on start or if a collision didn't trigger a new one (shouldn't happen with the logic above, but good for robustness)
        if fallingCircles.isEmpty {
            addFallingCircle(in: size)
        }
    }

    /// Adds a new falling circle at a random horizontal position just above the top edge.
    private func addFallingCircle(in size: CGSize) {
        print("Attempting to add new falling circle...")
        let radius = CGFloat.random(in: 0.02...0.05)
        let xPosition = CGFloat.random(in: radius...(1.0 - radius))
        let startingPosition = CGPoint(x: xPosition, y: -radius) // Start just above the top edge
        let color: Color = [.red, .blue, .orange, .purple].randomElement() ?? .red

        let newCircle = FallingCircle(
            position: startingPosition,
            radius: radius,
            color: color,
            speed: CGFloat.random(in: 0.005...0.015) // Speed in normalized units per frame
        )
        fallingCircles.append(newCircle)
        print("Added new falling circle with ID \(newCircle.id) to array. Total circles: \(fallingCircles.count).")
        print("Added new falling circle at \(newCircle.position)")
    }
}

// MARK: - Models

/// Represents a falling circle in the game.
struct FallingCircle: Identifiable, Sendable {
    let id = UUID()
    var position: CGPoint
    let radius: CGFloat
    let color: Color
    let speed: CGFloat
} 
