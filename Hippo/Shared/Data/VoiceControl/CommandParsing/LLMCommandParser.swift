//
//  LLMCommandParser.swift
//  Hippo
//
//  LLM-based voice command parser (v2 skeleton)
//  Uses OpenAI API for natural language understanding
//

import Foundation

/// LLM-based implementation of VoiceCommandParser
///
/// This parser sends ambiguous commands to an LLM (OpenAI) for interpretation.
/// It's more flexible than rule-based parsing but requires network and API key.
///
/// **Current Status: Skeleton Implementation**
/// - Request/Response structures are defined
/// - JSON mapping logic is implemented
/// - Actual network calls are marked as TODO
///
/// Usage:
/// ```swift
/// let parser = LLMCommandParser(
///     apiKey: "sk-...",
///     endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!
/// )
/// let intent = try await parser.parse(text: "왼쪽으로 살짝 돌려줘")
/// ```
public struct LLMCommandParser: VoiceCommandParser {

    // MARK: - Properties

    private let apiKey: String
    private let endpoint: URL
    private let model: String

    // MARK: - Initialization

    public init(
        apiKey: String,
        endpoint: URL,
        model: String = "gpt-4o-mini"
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
    }

    // MARK: - VoiceCommandParser

    public func parse(text: String) async throws -> VoiceCommandIntent {
        // Build request payload
        let request = buildRequest(for: text)

        // NOTE: This is a skeleton implementation
        // Currently returns .unknown without calling LLM
        // Future implementation will:
        //   1. Call sendRequest(request) to hit OpenAI API
        //   2. Call mapResponseToIntent() to convert JSON → VoiceCommandIntent
        //   3. Return the parsed intent
        //
        // TODO: Uncomment when ready to connect to OpenAI:
        // let response = try await sendRequest(request)
        // return try mapResponseToIntent(response, originalText: text)

        return .unknown(rawText: text)
    }
}

// MARK: - Request Building

private extension LLMCommandParser {

    /// Build OpenAI API request payload
    func buildRequest(for text: String) -> LLMRequest {
        let systemPrompt = """
        You are a voice command parser for a medical AR application.
        The user will mostly speak Korean (medical staff in an operating room).

        Available commands:
        - HideUI: Hide the user interface panel
        - ShowUI: Show the user interface panel
        - ClosePanel: Close the current panel or window
        - RotateEntity: Rotate a 3D entity (requires direction and angle)
        - ShowVideoOnly: Display only the video feed (hide all UI)

        Parse the user's Korean voice command and return the intent in JSON format.

        Response format:
        {
          "intent": "CommandName",
          "parameters": { ... }
        }

        For RotateEntity, include:
        {
          "intent": "RotateEntity",
          "parameters": {
            "direction": "left" | "right" | "up" | "down",
            "angle": <number>
          }
        }

        If the command is unclear, return:
        {
          "intent": "Unknown",
          "parameters": {}
        }
        """

        let userMessage = """
        Parse this voice command: "\(text)"
        """

        return LLMRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userMessage)
            ],
            temperature: 0.3,
            maxTokens: 150
        )
    }
}

// MARK: - Network Layer (TODO)

private extension LLMCommandParser {

    /// Send request to OpenAI API
    ///
    /// TODO: Implement actual HTTP request using URLSession
    /// TODO: Add proper error handling (network, timeout, rate limit)
    /// TODO: Add retry logic for transient failures
    func sendRequest(_ request: LLMRequest) async throws -> LLMResponse {
        // TODO: Implementation
        // let (data, response) = try await URLSession.shared.data(for: urlRequest)
        // let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
        // return llmResponse

        fatalError("LLMCommandParser.sendRequest() not yet implemented")
    }
}

// MARK: - Response Mapping

private extension LLMCommandParser {

    /// Map LLM response to VoiceCommandIntent
    ///
    /// This method converts the JSON response from OpenAI into our domain model.
    func mapResponseToIntent(_ response: LLMResponse, originalText: String) throws -> VoiceCommandIntent {
        guard let choice = response.choices.first,
              let content = choice.message.content else {
            throw VoiceControlError.parsingFailed(reason: "Empty LLM response")
        }

        // Parse the JSON content
        guard let data = content.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(LLMIntentResponse.self, from: data) else {
            throw VoiceControlError.parsingFailed(reason: "Invalid JSON in LLM response")
        }

        // Map to VoiceCommandIntent
        return try mapIntentResponse(parsed, originalText: originalText)
    }

    /// Map LLMIntentResponse to VoiceCommandIntent
    func mapIntentResponse(_ response: LLMIntentResponse, originalText: String) throws -> VoiceCommandIntent {
        switch response.intent.lowercased() {
        case "closemenu", "hideui":
            return .closeMenu

        case "openmenu", "showui":
            return .openMenu

        case "closevideo", "closepanel":
            return .closeVideo

        case "showvideo", "showvideoonly":
            return .showVideo

        case "rotateentity":
            return try parseRotateEntityFromLLM(response.parameters, originalText: originalText)

        case "unknown":
            return .unknown(rawText: originalText)

        default:
            return .unknown(rawText: originalText)
        }
    }

    /// Parse RotateEntity parameters from LLM response
    func parseRotateEntityFromLLM(_ parameters: [String: AnyCodable], originalText: String) throws -> VoiceCommandIntent {
        guard let directionString = parameters["direction"]?.stringValue,
              let direction = RotationDirection(rawValue: directionString) else {
            throw VoiceControlError.invalidParameters("Missing or invalid rotation direction")
        }

        guard let angle = parameters["angle"]?.doubleValue else {
            throw VoiceControlError.invalidParameters("Missing rotation angle")
        }

        guard angle > 0 && angle <= 360 else {
            throw VoiceControlError.invalidParameters("Angle must be between 0 and 360")
        }

        return .rotateEntity(direction: direction, angle: angle)
    }
}

// MARK: - Data Models

/// OpenAI API request structure
private struct LLMRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int

    struct Message: Encodable {
        let role: String
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

/// OpenAI API response structure
private struct LLMResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}

/// LLM intent response (parsed from message content)
///
/// Example:
/// ```json
/// {
///   "intent": "RotateEntity",
///   "parameters": { "direction": "left", "angle": 30 }
/// }
/// ```
private struct LLMIntentResponse: Decodable {
    let intent: String
    let parameters: [String: AnyCodable]
}

/// Type-erased Codable wrapper for dynamic JSON values
private struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    var stringValue: String? { value as? String }
    var doubleValue: Double? {
        if let double = value as? Double {
            return double
        } else if let int = value as? Int {
            return Double(int)
        }
        return nil
    }
}
