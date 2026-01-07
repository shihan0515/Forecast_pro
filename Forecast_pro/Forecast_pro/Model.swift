import Foundation

// MARK: - Model 修正版
// 明確標記為 nonisolated 以避免 MainActor 隔離問題
struct WeatherData: Codable, Sendable {
    let daily: Daily
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        daily = try container.decode(Daily.self, forKey: .daily)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(daily, forKey: .daily)
    }
    
    enum CodingKeys: String, CodingKey {
        case daily
    }
}

struct Daily: Codable, Sendable {
    let time: [String]
    let temperature_2m_max: [Double]
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decode([String].self, forKey: .time)
        temperature_2m_max = try container.decode([Double].self, forKey: .temperature_2m_max)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(time, forKey: .time)
        try container.encode(temperature_2m_max, forKey: .temperature_2m_max)
    }
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature_2m_max
    }
}

struct OpenAIResponse: Codable, Sendable {
    struct Choice: Codable, Sendable {
        struct Message: Codable, Sendable {
            let content: String
            
            nonisolated init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                // 使用 decodeIfPresent 以防 content 可能為空
                content = try container.decode(String.self, forKey: .content)
            }
            
            nonisolated func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(content, forKey: .content)
            }
            
            enum CodingKeys: String, CodingKey {
                case content
            }
        }
        
        let message: Message
        
        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            message = try container.decode(Message.self, forKey: .message)
        }
        
        nonisolated func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(message, forKey: .message)
        }
        
        enum CodingKeys: String, CodingKey {
            case message
        }
    }
    
    let choices: [Choice]
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        choices = try container.decode([Choice].self, forKey: .choices)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(choices, forKey: .choices)
    }
    
    enum CodingKeys: String, CodingKey {
        case choices
    }
}

struct WeatherItem: Identifiable, Sendable {
    let id = UUID()
    let date: String
    let temp: Double
}