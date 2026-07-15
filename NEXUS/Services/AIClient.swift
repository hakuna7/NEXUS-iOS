import Foundation

enum AIClientError: LocalizedError {
    case missingConfiguration
    case invalidEndpoint
    case badResponse(Int, String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "请先在设置中填写 API Key。"
        case .invalidEndpoint: "模型接口地址无效。"
        case let .badResponse(code, body): "模型接口返回错误 \(code)：\(body.prefix(180))"
        case .emptyResponse: "模型没有返回内容。"
        }
    }
}

actor AIClient {
    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        let choices: [Choice]
    }

    func complete(settings: AppSettings, apiKey: String, messages: [ChatMessage], temperature: Double = 0.2) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingConfiguration
        }
        guard let url = completionURL(from: settings.endpoint) else {
            throw AIClientError.invalidEndpoint
        }

        let body = RequestBody(
            model: settings.model,
            messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            temperature: temperature
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? "未知错误"
            throw AIClientError.badResponse(status, body)
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let result = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !result.isEmpty else {
            throw AIClientError.emptyResponse
        }
        return result
    }

    private func completionURL(from raw: String) -> URL? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        if !value.hasSuffix("/chat/completions") {
            value += "/chat/completions"
        }
        return URL(string: value)
    }
}
