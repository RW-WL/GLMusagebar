import Foundation

struct UsageData {
    let planLevel: String
    let watermark5h: Double
    let watermark7d: Double
    let reset5h: Date?
    let reset7d: Date?
    let tokens24h: Int
    let calls24h: Int
    let tokens7d: Int
    let calls7d: Int
    let models24h: [ModelUsage]
    let models7d: [ModelUsage]
    let mcpUsed: Int
    let mcpCap: Int
    let mcpDetails: [MCPDetail]
    let lastUpdated: Date

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 3600
    }

    static let empty = UsageData(
        planLevel: "-", watermark5h: 0, watermark7d: 0,
        reset5h: nil, reset7d: nil,
        tokens24h: 0, calls24h: 0, tokens7d: 0, calls7d: 0,
        models24h: [], models7d: [],
        mcpUsed: 0, mcpCap: 0, mcpDetails: [],
        lastUpdated: .distantPast
    )
}

struct ModelUsage {
    let name: String
    let tokens: Int
    let percentage: Double

    var displayTokens: String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.0fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }
}

struct MCPDetail {
    let code: String
    let usage: Int
}