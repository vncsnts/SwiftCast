import Foundation
import AVFoundation

/// Manages sound effects for the game, handling multiple simultaneous sounds.
@MainActor
final class SoundEffectsManager: NSObject, ObservableObject {
    private let audioQueue = DispatchQueue(label: "com.elliegame.audio", qos: .userInteractive, attributes: .concurrent)
    private let maxSimultaneousSounds = 8
    private var activePlayers: [UUID: AVAudioPlayer] = [:]
    
    override init() {
        super.init()
    }
    
    /// Plays a pop sound effect with proper handling of multiple simultaneous sounds.
    func playPopSound() {
        // Check if we've reached the maximum number of simultaneous sounds
        guard activePlayers.count < maxSimultaneousSounds else { return }
        
        let soundID = UUID()
        
        // Play sound on dedicated audio queue
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Use system sound URL
            guard let soundURL = URL(string: "/System/Library/Sounds/Tink.aiff") else {
                print("Failed to find system sound")
                return
            }
            
            do {
                let player = try AVAudioPlayer(contentsOf: soundURL)
                player.prepareToPlay()
                
                // Set up delegate to handle completion
                player.delegate = self
                
                // Store player and play
                Task { @MainActor in
                    self.activePlayers[soundID] = player
                }
                
                player.play()
            } catch {
                print("Failed to play sound: \(error)")
                Task { @MainActor in
                    self.activePlayers.removeValue(forKey: soundID)
                }
            }
        }
    }
    
    /// Stops all currently playing sounds.
    func stopAllSounds() {
        audioQueue.async { [weak self] in
            Task { @MainActor in
                self?.activePlayers.values.forEach { $0.stop() }
                self?.activePlayers.removeAll()
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension SoundEffectsManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            // Remove the finished player
            if let (id, _) = activePlayers.first(where: { $0.value === player }) {
                activePlayers.removeValue(forKey: id)
            }
        }
    }
} 
