import SwiftUI
import AVFoundation
import Starscream
import Combine
import Speech

struct PromptManager {
    func generatePrompt(for userInput: String) -> String {
        let context = """
        If the spoken input is in English, translate it into Pakistani Punjabi using the proper Gurmukhi script. Ensure that the translation reflects the Pakistani Punjabi dialect, not Hindi Punjabi.

        If the spoken input is in Romanized Punjabi (Punjabi written with English letters), translate it into English. If some words are unclear, make an educated guess based on context to provide the best possible translation.

        Only provide the translated text without any additional explanations or text.
        """
        return context + userInput
    }
}

struct ListeningBarsView: View {
    var audioLevels: [Float]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(audioLevels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: 8, height: CGFloat(level * 60))
            }
        }
    }
}


struct LoadingIndicatorView: View {
    @State private var isAnimating: Bool = false

    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.7)
            .stroke(Color.white, lineWidth: 6)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .frame(width: 150, height: 150)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    self.isAnimating = true
                }
            }
    }
}

struct ContentView: View {
    @ObservedObject private var speechRecognizer = SpeechRecognizer()
    @State private var statusMessage: String = "Ready to translate"
    @State private var audioLevels: [Float] = Array(repeating: 0.2, count: 5)
    @State private var showStopButton: Bool = false
    @State private var isLoading: Bool = false
    private let ttsService = OpenAITTS()

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {

                ZStack {
                    if showStopButton {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 6)
                            .frame(width: 120, height: 120)
                            .onTapGesture {
                                stopRecording()
                            }
                    }

                    if isLoading {
                        LoadingIndicatorView()
                            .frame(width: 175, height: 175)
                    } else if speechRecognizer.isListening {
                        ListeningBarsView(audioLevels: audioLevels)
                            .frame(width: 150, height: 100)
                            .onTapGesture {
                                stopRecording()
                            }
                    } else {
                        Image(systemName: "waveform")
                            .resizable()
                            .frame(width: 150, height: 90)
                            .foregroundColor(.white)
                    }
                }

                Text(statusMessage)
                    .foregroundColor(.white)
                    .padding()

                if !isLoading {
                    HStack(spacing: 20) {
                        Button(action: {
                            speechRecognizer.selectedLanguage = "english"
                            startRecording()
                        }) {
                            Text("Start English")
                                .frame(width: 140, height: 140)
                                .background(Color.clear)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(70)
                        
                        Button(action: {
                            speechRecognizer.selectedLanguage = "urdu"
                            startRecording()
                        }) {
                            Text("Start Punjabi")
                                .frame(width: 140, height: 140)
                                .background(Color.clear)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(70)
                    }
                }
            }
            .padding()
        }
    }

    func startRecording() {
        try? speechRecognizer.startRecording(audioLevels: $audioLevels)
        statusMessage = "Listening..."
        showStopButton = true
        isLoading = false
    }

    func stopRecording() {
        speechRecognizer.stopRecording()
        statusMessage = "Processing..."
        showStopButton = false
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            translateText()
        }
    }

    func translateText() {
        let promptManager = PromptManager()
        let fullPrompt = promptManager.generatePrompt(for: speechRecognizer.recognizedText)

        let urlString = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer ADD OPENAI KEY HERE", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [["role": "user", "content": fullPrompt]],
            "max_tokens": 150,
            "temperature": 0.5
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    statusMessage = "Failed to fetch data: \(error?.localizedDescription ?? "Unknown error")"
                    isLoading = false
                }
                return
            }

            if let responseDictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let choices = responseDictionary["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {

                DispatchQueue.main.async {
                    statusMessage = "Translation complete"
                    isLoading = false
                    speakTranslation(content)
                }
            } else {
                DispatchQueue.main.async {
                    statusMessage = "Error parsing data or no content found"
                    isLoading = false
                }
            }
        }.resume()
    }

    func speakTranslation(_ text: String) {
        ttsService.speak(text)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
