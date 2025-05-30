import SwiftUI
import Combine

@MainActor
final class CameraGameViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var fallingCircles: [FallingCircle] = []
    @Published var popAnimations: [UUID: PopAnimation] = [:]
    @Published var lastHandPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    // MARK: - Dependencies
    private let cameraManager: CameraRecordManager
    private let soundManager: SoundEffectsManager
    
    // MARK: - Game Configuration
    private let maxCircles = 5
    private let circleSpawnInterval: TimeInterval = 1.5
    private let circleSpeedRange: ClosedRange<CGFloat> = 0.003...0.008
    private let minConfidence: Float = 0.3
    private let ballRadius: CGFloat = 0.08
    
    // MARK: - Game State
    private var lastSpawnTime: Date = Date()
    private var gameLoopCancellable: AnyCancellable?
    
    init(cameraManager: CameraRecordManager, soundManager: SoundEffectsManager) {
        self.cameraManager = cameraManager
        self.soundManager = soundManager
        setupGameLoop()
    }
    
    // MARK: - Game Loop Setup
    private func setupGameLoop() {
        gameLoopCancellable = Timer.publish(every: 1.0/60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateGame()
            }
    }
    
    // MARK: - Game Logic
    func updateGame() {
        // Update falling circles' positions
        for index in fallingCircles.indices {
            fallingCircles[index].position.y += fallingCircles[index].speed
        }
        
        // Remove circles that fall off the bottom
        fallingCircles.removeAll { $0.position.y > (1.0 + $0.radius) }
        
        // Update pop animations
        for (id, animation) in popAnimations {
            if animation.isComplete {
                popAnimations.removeValue(forKey: id)
            }
        }
        
        // Spawn new circles if needed
        let now = Date()
        if fallingCircles.count < maxCircles && now.timeIntervalSince(lastSpawnTime) >= circleSpawnInterval {
            addFallingCircle()
            lastSpawnTime = now
        }
        
        // Handle collisions
        handleCollisions()
    }
    
    private func handleCollisions() {
        var indicesToRemove: [Int] = []
        
        if let handPoints = cameraManager.handPoints {
            let validPoints = handPoints.filter { $0.value.confidence > minConfidence }
            
            for index in fallingCircles.indices {
                let circle = fallingCircles[index]
                
                // Skip circles that are already being popped
                if popAnimations[circle.id] != nil { continue }
                
                for (_, point) in validPoints {
                    // Flip both x and y coordinates to match the camera preview
                    let handPoint = CGPoint(x: 1.0 - point.location.x, y: 1.0 - point.location.y)
                    
                    let dx = handPoint.x - circle.position.x
                    let dy = handPoint.y - circle.position.y
                    let distanceSquared = dx * dx + dy * dy
                    
                    // Slightly larger collision radius for better feel
                    let collisionRadius = circle.radius * 1.2
                    
                    if distanceSquared < (collisionRadius * collisionRadius) {
                        // Start pop animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            popAnimations[circle.id] = PopAnimation(scale: 1.5, opacity: 0)
                        }
                        
                        indicesToRemove.append(index)
                        break
                    }
                }
            }
        }
        
        // Remove circles after animation
        for index in indicesToRemove.reversed() {
            let circle = fallingCircles[index]
            // Wait for animation to complete before removing
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                if let index = fallingCircles.firstIndex(where: { $0.id == circle.id }) {
                    fallingCircles.remove(at: index)
                    soundManager.playPopSound()
                }
            }
        }
    }
    
    func addFallingCircle() {
        let radius = CGFloat.random(in: 0.03...0.06)
        let xPosition = CGFloat.random(in: radius...(1.0 - radius))
        let startingPosition = CGPoint(x: xPosition, y: -radius)
        let color: Color = [.red, .blue, .orange, .purple].randomElement() ?? .red
        
        let newCircle = FallingCircle(
            position: startingPosition,
            radius: radius,
            color: color,
            speed: CGFloat.random(in: circleSpeedRange)
        )
        fallingCircles.append(newCircle)
    }
    
    func updateHandPosition(_ newPosition: CGPoint?) {
        if let position = newPosition {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                lastHandPosition = position
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        gameLoopCancellable?.cancel()
    }
}

// MARK: - Models
struct FallingCircle: Identifiable, Sendable {
    let id = UUID()
    var position: CGPoint
    let radius: CGFloat
    let color: Color
    let speed: CGFloat
}

struct PopAnimation {
    var scale: CGFloat
    var opacity: CGFloat
    var isComplete: Bool { opacity <= 0 }
} 
