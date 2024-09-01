import Foundation
import AVFoundation

class OpenAITTS: NSObject, AVAudioPlayerDelegate {
    private enum Constants {
        static let apiKey = "ADD OPENAI KEY HERE"
        static let url = URL(string: "https://api.openai.com/v1/audio/speech")
    }

    private var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        return session
    }()
    
    private var audioPlayer: AVAudioPlayer?

    func speak(_ text: String) {
        guard let request = self.request(text) else {
            print("No request")
            return
        }
        self.send(request: request)
    }

    private func send(request: URLRequest) {
        let task = self.urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to fetch data: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {

            } else {
                print("No HTTP response received")
            }

            guard let data = data else {
                print("No data received")
                return
            }

            // The response is audio data and should be handled as such
            DispatchQueue.main.async {
                self.playAudio(audioData: data)
            }
        }
        task.resume()
    }

    private func request(_ text: String) -> URLRequest? {
        guard let baseURL = Constants.url else {
            print("Base URL is invalid")
            return nil
        }

        var request = URLRequest(url: baseURL)
        let parameters: [String: Any] = [
            "model": "tts-1",
            "voice": "nova",
            "response_format": "mp3",
            "speed": "0.98",
            "input": text
        ]

        request.addValue("Bearer \(Constants.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch {
            print("Error serializing JSON: \(error.localizedDescription)")
            return nil
        }
        
        print("Request URL: \(request.url?.absoluteString ?? "N/A")")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Body: \(String(data: request.httpBody!, encoding: .utf8) ?? "Invalid Body")")
        
        return request
    }

    private func playAudio(audioData: Data) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)

            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }


    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayer = nil
    }
}
