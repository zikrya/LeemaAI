import AVFoundation
import SwiftUI
import Starscream
import Combine
import Speech

class SpeechRecognizer: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private let gladiaKey = "GLADIA API HERE"
    private var socket: WebSocket?
    @Published var recognizedText = ""
    @Published var isListening = false
    @Published var selectedLanguage: String = "english"

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func initializeSocket() {
        var request = URLRequest(url: URL(string: "wss://api.gladia.io/audio/text/audio-transcription")!)
        request.setValue(gladiaKey, forHTTPHeaderField: "x-gladia-key")
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }

    func startRecording(audioLevels: Binding<[Float]>) throws {
        stopRecording()
        initializeSocket()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let bus = 0
        let bufferSize: AVAudioFrameCount = 1024

        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: true) else {
            fatalError("Failed to create required audio format.")
        }

        inputNode.installTap(onBus: bus, bufferSize: bufferSize, format: format) { [weak self] (buffer, when) in
            guard let self = self else { return }
            let level = self.calculateAudioLevel(buffer: buffer)
            DispatchQueue.main.async {

                var updatedLevels = audioLevels.wrappedValue
                for i in 0..<updatedLevels.count {
                    updatedLevels[i] = level * Float.random(in: 1.5...2.5) 
                }
                audioLevels.wrappedValue = updatedLevels
            }
            if let frame = self.bufferToBase64(buffer: buffer) {
                self.sendAudioFrame(base64Frame: frame)
            }
        }

        try audioEngine!.start()
        isListening = true
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        socket?.write(string: "{\"event\": \"terminate\"}")
        socket?.disconnect()

        isListening = false

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false)
    }

    private func bufferToBase64(buffer: AVAudioPCMBuffer) -> String? {
        let frameCount = Int(buffer.frameLength)
        guard let channelData = buffer.int16ChannelData else {
            return nil
        }

        let data = Data(buffer: UnsafeBufferPointer(start: channelData[0], count: frameCount))
        return data.base64EncodedString()
    }

    private func sendAudioFrame(base64Frame: String) {
        let frameData: [String: Any] = [
            "frames": base64Frame
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: frameData, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket?.write(string: jsonString)
        }
    }

    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        let bufferPointer = buffer.floatChannelData?.pointee
        let bufferSize = Int(buffer.frameLength)
        var rms: Float = 0.0

        if let bufferPointer = bufferPointer {
            for i in 0..<bufferSize {
                rms += bufferPointer[i] * bufferPointer[i]
            }
            rms = sqrt(rms / Float(bufferSize))
        }

        return max(0.2, min(2.0, rms * 40))
    }
}

extension SpeechRecognizer: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(_):
            let customVocabulary = [
                "ਮੈਂ", "ਤੁਹਾਡਾ", "ਇਹ", "ਕੀ", "ਹੈ", "ਪੰਜਾਬੀ", "ਸੱਚ", "ਗੱਲ", "ਕਰਨਾ", "ਕਮਹ",
                "ਤੁਸੀਂ", "ਕਰਦੇ", "ਕਰਦੀ", "ਕਰਦਾ", "ਕੀਹ", "ਪਤਾ", "ਇੱਕ", "ਅਜਿਹਾ", "ਕਦੇ"
            ].joined(separator: ",")

            let configMessage: [String: Any] = [
                "x_gladia_key": gladiaKey,
                "encoding": "wav/pcm",        // Adjusted to a supported format
                "sample_rate": 48000,         // Match this to your actual hardware sample rate
                "language_behaviour": "manual",
                "language": selectedLanguage, // Use the selected language here
                "frames_format": "base64",
                "model_type": "accurate",
                "audio_enhancer": true,       // Enable audio enhancement
                "endpointing": 200,           // Adjust to manage segments
                "transcription_hint": customVocabulary // Add custom vocabulary
            ]
            
            if let configData = try? JSONSerialization.data(withJSONObject: configMessage, options: []),
               let configString = String(data: configData, encoding: .utf8) {
                socket?.write(string: configString)
                print("Sent initial configuration message: \(configString)")
            }

        case .text(let text):
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("Parsed JSON: \(json)")
                if let event = json["event"] as? String, event == "transcript",
                   let transcription = json["transcription"] as? String {
                    DispatchQueue.main.async {
                        self.recognizedText = transcription
                    }
                }
            } else {
                print("Failed to parse JSON from the text")
            }

        case .error(let error):
            print("WebSocket error: \(error?.localizedDescription ?? "Unknown error")")
        case .disconnected(let reason, let code):
            print("WebSocket disconnected: \(reason) with code: \(code)")
        default:
            break
        }
    }
}
