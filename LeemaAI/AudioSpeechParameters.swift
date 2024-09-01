import Foundation

public struct AudioSpeechParameters: Encodable {

    /// One of the available TTS models: tts-1 or tts-1-hd
    let model: String
    /// The text to generate audio for. The maximum length is 4096 characters.
    let input: String
    /// The voice to use when generating the audio. Supported voices are alloy, echo, fable, onyx, nova, and shimmer.
    let voice: String
    /// The format to audio in. Supported formats are mp3, opus, aac, and flac. Defaults to mp3.
    let responseFormat: String?
    /// The speed of the generated audio. Select a value from 0.25 to 4.0. Defaults to 1.0.
    let speed: Double?

    public enum TTSModel: String {
        case tts1 = "tts-1"
        case tts1HD = "tts-1-hd"
    }

    public enum Voice: String {
        case alloy
        case echo
        case fable
        case onyx
        case nova
        case shimmer
    }

    public enum ResponseFormat: String {
        case mp3
        case opus
        case aac
        case flac
    }

    public init(
        model: TTSModel,
        input: String,
        voice: Voice,
        responseFormat: ResponseFormat? = nil,
        speed: Double? = nil
    ) {
        self.model = model.rawValue
        self.input = input
        self.voice = voice.rawValue
        self.responseFormat = responseFormat?.rawValue
        self.speed = speed
    }
}

public struct AudioSpeechObject: Decodable {
    /// The audio file content data.
    public let output: Data
}
