import Foundation

enum ClaudeModel: String, CaseIterable, Identifiable {
    case opus = "claude-opus-5-5"
    case sonnet = "claude-sonnet-5-5"
    case haiku = "claude-haiku-5-5"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .opus: return "Claude Opus 5.5"
        case .sonnet: return "Claude Sonnet 5.5"
        case .haiku: return "Claude Haiku 5.5"
        }
    }
    var detail: String {
        switch self {
        case .opus: return "Most capable · best extraction quality"
        case .sonnet: return "Fast and capable · lower cost"
        case .haiku: return "Fastest · lowest cost"
        }
    }
    /// Server-side refusal fallback ("default" form) is offered on Opus and Sonnet.
    var supportsDefaultFallback: Bool { self != .haiku }
}

enum ClaudeError: LocalizedError {
    case noKey
    case http(Int, String)
    case refusal
    case truncated
    case badResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .noKey: return "Add your Claude API key in Settings → AI Assistant to use AI features."
        case .http(401, _): return "Your Claude API key was rejected. Check it in Settings → AI Assistant."
        case .http(429, _): return "Too many AI requests right now. Wait a moment and try again."
        case .http(529, _), .http(503, _): return "The AI service is busy. Please try again shortly."
        case .http(let code, let msg): return "AI request failed (\(code)). \(msg)"
        case .refusal: return "The AI declined this request."
        case .truncated: return "The AI response was cut off. Please try again."
        case .badResponse: return "The AI returned a response the app couldn't read."
        case .network(let m): return "Couldn't reach the AI service: \(m)"
        }
    }
}

/// Minimal client for the Claude Messages API (POST /v1/messages) over URLSession.
/// The API key lives in the Keychain and is only ever sent to api.anthropic.com.
enum ClaudeClient {
    static let keychainKey = "anthropicAPIKey"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2026-10-21"
    private static let fallbackBeta = "server-side-fallback-2026-07-01"

    static var apiKey: String? {
        guard let k = KeychainHelper.read(keychainKey), !k.isEmpty else { return nil }
        return k
    }

    static var isConfigured: Bool { apiKey != nil }

    static var model: ClaudeModel {
        ClaudeModel(rawValue: UserDefaults.standard.string(forKey: SettingsKey.aiModel) ?? "") ?? .opus
    }

    // MARK: Content helpers

    static func text(_ s: String) -> [String: Any] { ["type": "text", "text": s] }

    static func image(_ jpeg: Data) -> [String: Any] {
        ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]]
    }

    static func user(_ content: [[String: Any]]) -> [String: Any] { ["role": "user", "content": content] }

    // MARK: Requests

    struct Response {
        let json: [String: Any]
        var stopReason: String { json["stop_reason"] as? String ?? "" }
        var content: [[String: Any]] { json["content"] as? [[String: Any]] ?? [] }
        var text: String {
            content.filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
        }
    }

    /// Sends one request. Handles `pause_turn` (server tools) by continuing the turn.
    static func send(system: String,
                     messages: [[String: Any]],
                     schema: [String: Any]? = nil,
                     tools: [[String: Any]]? = nil,
                     effort: String = "medium",
                     maxTokens: Int = 16000) async throws -> Response {
        var msgs = messages
        for _ in 0..<4 {
            let response = try await post(system: system, messages: msgs, schema: schema, tools: tools,
                                          effort: effort, maxTokens: maxTokens)
            switch response.stopReason {
            case "pause_turn":
                msgs.append(["role": "assistant", "content": response.content])
                continue
            case "refusal":
                throw ClaudeError.refusal
            case "max_tokens":
                throw ClaudeError.truncated
            default:
                return response
            }
        }
        throw ClaudeError.badResponse
    }

    /// Sends a request whose answer must match `schema`, and decodes it.
    static func structured(system: String, content: [[String: Any]], schema: [String: Any],
                           effort: String = "medium") async throws -> [String: Any] {
        let r = try await send(system: system, messages: [user(content)], schema: schema, effort: effort)
        guard let obj = parseJSONObject(r.text) else { throw ClaudeError.badResponse }
        return obj
    }

    private static func buildBody(system: String, messages: [[String: Any]], schema: [String: Any]?,
                                  tools: [[String: Any]]?, effort: String, maxTokens: Int,
                                  stream: Bool, withFallback: Bool) -> [String: Any] {
        var outputConfig: [String: Any] = ["effort": effort]
        if let schema { outputConfig["format"] = ["type": "json_schema", "schema": schema] }
        var body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": maxTokens,
            "system": system,
            "messages": messages,
            "output_config": outputConfig
        ]
        if let tools { body["tools"] = tools }
        if stream { body["stream"] = true }
        if withFallback { body["fallbacks"] = "default" }
        return body
    }

    private static func makeRequest(body: [String: Any], withFallback: Bool, key: String) throws -> URLRequest {
        var req = URLRequest(url: endpoint, timeoutInterval: 240)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        if withFallback { req.setValue(fallbackBeta, forHTTPHeaderField: "anthropic-beta") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private static func post(system: String, messages: [[String: Any]], schema: [String: Any]?,
                             tools: [[String: Any]]?, effort: String, maxTokens: Int) async throws -> Response {
        guard let key = apiKey else { throw ClaudeError.noKey }
        var useFallback = model.supportsDefaultFallback
        for attempt in 0..<2 {
            let body = buildBody(system: system, messages: messages, schema: schema, tools: tools, effort: effort,
                                 maxTokens: maxTokens, stream: false, withFallback: useFallback)
            let req = try makeRequest(body: body, withFallback: useFallback, key: key)
            let data: Data, resp: URLResponse
            do {
                (data, resp) = try await URLSession.shared.data(for: req)
            } catch {
                throw ClaudeError.network(error.localizedDescription)
            }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            if code == 200 { return Response(json: json) }
            let message = ((json["error"] as? [String: Any])?["message"] as? String) ?? ""
            // If the optional fallback feature isn't accepted for this request, retry once without it.
            if code == 400, useFallback, attempt == 0, message.lowercased().contains("fallback") {
                useFallback = false
                continue
            }
            throw ClaudeError.http(code, message)
        }
        throw ClaudeError.badResponse
    }

    /// Streams the text of a reply, for the chat assistant.
    static func stream(system: String, messages: [[String: Any]], effort: String = "low") -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard let key = apiKey else { continuation.finish(throwing: ClaudeError.noKey); return }
                let useFallback = model.supportsDefaultFallback
                do {
                    let body = buildBody(system: system, messages: messages, schema: nil, tools: nil, effort: effort,
                                         maxTokens: 16000, stream: true, withFallback: useFallback)
                    let req = try makeRequest(body: body, withFallback: useFallback, key: key)
                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    if code != 200 {
                        var raw = ""
                        for try await line in bytes.lines { raw += line }
                        let json = (try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any]
                        let msg = ((json?["error"] as? [String: Any])?["message"] as? String) ?? ""
                        throw ClaudeError.http(code, msg)
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard let obj = (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) as? [String: Any] else { continue }
                        switch obj["type"] as? String {
                        case "content_block_delta":
                            if let delta = obj["delta"] as? [String: Any],
                               delta["type"] as? String == "text_delta",
                               let t = delta["text"] as? String {
                                continuation.yield(t)
                            }
                        case "message_delta":
                            if let d = obj["delta"] as? [String: Any], d["stop_reason"] as? String == "refusal" {
                                throw ClaudeError.refusal
                            }
                        case "error":
                            let msg = ((obj["error"] as? [String: Any])?["message"] as? String) ?? "Stream error"
                            throw ClaudeError.http(500, msg)
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    if let e = error as? ClaudeError { continuation.finish(throwing: e) }
                    else if error is CancellationError { continuation.finish() }
                    else { continuation.finish(throwing: ClaudeError.network(error.localizedDescription)) }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Quick check used by Settings → "Test Connection".
    static func testConnection() async throws -> String {
        let r = try await send(system: "Reply with exactly: OK", messages: [user([text("Ping")])], effort: "low", maxTokens: 2000)
        return r.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Finds the first JSON object in a string (handles stray prose or code fences).
    static func parseJSONObject(_ text: String) -> [String: Any]? {
        if let d = text.data(using: .utf8), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] { return o }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else { return nil }
        let slice = String(text[start...end])
        return (try? JSONSerialization.jsonObject(with: Data(slice.utf8))) as? [String: Any]
    }
}
