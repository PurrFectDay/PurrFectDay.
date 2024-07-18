import AVFoundation

class BackgroundMusicPlayer {
    static let shared = BackgroundMusicPlayer()
    var player: AVAudioPlayer?
    
    private init() {}
    
    func play(fileName: String, fileType: String = "mp3") {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileType) else {
            print("Music file not found.")
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            // 초기 볼륨 설정
            
            let volume = UserDefaults.standard.float(forKey: "BackgroundInitialVolume")
            if volume != 0.0 {
                player?.volume = volume
                // 반복 재생
                player?.numberOfLoops = -1 // Loop indefinitely
                player?.play()
                UserDefaults.standard.setValue(fileName, forKey: "BackgroundMusicName")
            }
        } catch {
            print("Error playing music: \(error.localizedDescription)")
        }
    }
    
    func pause() {
        player?.pause()
    }
    
    func stop() {
        player?.stop()
    }
    
    func setVolume(_ volume: Float) {
        player?.volume = volume
    }
    
    // 사용자 설정값 저장
    func saveInitialVolume(_ volume: Float) {
        UserDefaults.standard.set(volume, forKey: "BackgroundInitialVolume")
    }
    
    // 사용자 설정값 가져오기
    func getInitialVolume() -> Float {
        return UserDefaults.standard.float(forKey: "BackgroundInitialVolume")
    }
}

class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()
    private var players: [String: AVAudioPlayer] = [:]
    
    private init() {}
    
    func play(fileName: String, fileType: String = "mp3") {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileType) else {
            print("Sound effect file not found.")
            return
        }
        
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            players[fileName] = player
            let volume = UserDefaults.standard.float(forKey: "SoundEffectInitialVolume")
            
            if volume != 0.0 {
                player.volume = volume * 10
                player.numberOfLoops = 1
                
                player.play()
                UserDefaults.standard.setValue(fileName, forKey: "SoundEffectFileName")
            }
        } catch {
            print("Error playing sound effect: \(error.localizedDescription)")
        }
    }
    
    func stop(filename: String) {
        players[filename]?.stop()
        players[filename] = nil
    }
    
    func setVolume(_ volume: Float) {
        for (_, player) in players {
            player.volume = volume
        }
    }
    
    // 사용자 설정값 저장
    func saveInitialVolume(_ volume: Float) {
        UserDefaults.standard.set(volume, forKey: "SoundEffectInitialVolume")
    }
    
    // 사용자 설정값 가져오기
    func getInitialVolume() -> Float {
        return UserDefaults.standard.float(forKey: "SoundEffectInitialVolume")
    }
}

