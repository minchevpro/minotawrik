import Foundation

enum TranscriptionError: Error, LocalizedError {
    case missingAPIKey
    case server(status: Int, message: String)
    case invalidResponse
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Не задан OpenAI API ключ. Откройте Настройки и вставьте ключ."
        case .server(let status, let message):
            return "Ошибка OpenAI (\(status)): \(message)"
        case .invalidResponse:
            return "Некорректный ответ от сервера OpenAI."
        case .network(let error):
            return "Сетевая ошибка: \(error.localizedDescription)"
        }
    }
}

/// Uploads a recorded audio file to OpenAI's `/v1/audio/transcriptions`
/// endpoint and returns the transcribed text.
struct OpenAITranscriptionService {
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func transcribe(fileURL: URL, model: TranscriptionModel, language: String) async throws -> String {
        guard let apiKey = KeychainHelper.loadAPIKey(), !apiKey.isEmpty else {
            throw TranscriptionError.missingAPIKey
        }

        let audioData: Data
        do {
            audioData = try Data(contentsOf: fileURL)
        } catch {
            throw TranscriptionError.network(error)
        }

        let boundary = "vectordictate-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(
            boundary: boundary,
            audioData: audioData,
            filename: fileURL.lastPathComponent,
            model: model.rawValue,
            language: language
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TranscriptionError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw TranscriptionError.server(status: httpResponse.statusCode, message: message)
        }

        struct TranscriptionResponse: Decodable { let text: String }
        guard let decoded = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) else {
            throw TranscriptionError.invalidResponse
        }

        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildMultipartBody(
        boundary: String,
        audioData: Data,
        filename: String,
        model: String,
        language: String
    ) -> Data {
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "model", value: model)
        if !language.isEmpty {
            appendField(name: "language", value: language)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}
