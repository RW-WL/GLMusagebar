import Foundation

enum UsageError: LocalizedError {
    case configNotFound
    case tokenNotFound
    case apiError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .configNotFound:
            return "找不到 ~/.openclaw/openclaw.json"
        case .tokenNotFound:
            return "openclaw.json 中未找到 zhipu apiKey"
        case .apiError(let msg):
            return "API 错误: \(msg)"
        case .parseError(let msg):
            return "解析错误: \(msg)"
        }
    }
}

actor UsageService {
    private let baseURL = "https://open.bigmodel.cn"
    private let configPath: String

    init(configPath: String? = nil) {
        self.configPath = configPath ?? NSHomeDirectory() + "/.openclaw/openclaw.json"
    }

    func fetchUsage() async throws -> UsageData {
        let token = try readToken()
        let tz = TimeZone(identifier: "Asia/Shanghai")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let now = Date()
        let since24h = cal.date(byAdding: .hour, value: -24, to: now)!
        let since7d = cal.date(byAdding: .day, value: -7, to: now)!

        async let model24h = queryModelUsage(token: token, since: since24h, until: now)
        async let quota = queryQuotaLimit(token: token)
        async let model7d = queryModelUsage(token: token, since: since7d, until: now)

        let (m24, q, m7d) = try await (model24h, quota, model7d)

        return UsageData(
            planLevel: q.level,
            watermark5h: q.wm5h,
            watermark7d: q.wm7d,
            reset5h: q.reset5h,
            reset7d: q.reset7d,
            tokens24h: m24.totalTokens,
            calls24h: m24.totalCalls,
            tokens7d: m7d.totalTokens,
            calls7d: m7d.totalCalls,
            models24h: m24.models,
            models7d: m7d.models,
            mcpUsed: q.mcpUsed,
            mcpCap: q.mcpCap,
            mcpDetails: q.mcpDetails,
            lastUpdated: now
        )
    }

    // MARK: - Config

    private func readToken() throws -> String {
        let url = URL(fileURLWithPath: configPath)
        guard let data = try? Data(contentsOf: url) else {
            throw UsageError.configNotFound
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [String: Any],
              let providers = models["providers"] as? [String: Any],
              let zhipu = providers["zhipu"] as? [String: Any],
              let apiKey = zhipu["apiKey"] as? String else {
            throw UsageError.tokenNotFound
        }
        return apiKey
    }

    // MARK: - API Calls

    private func queryModelUsage(token: String, since: Date, until: Date) async throws -> ModelUsageResponse {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")

        let params = "startTime=\(df.string(from: since))&endTime=\(df.string(from: until))"
        let urlString = "\(baseURL)/api/monitor/usage/model-usage?\(params)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        let json = try await request(urlString, token: token)
        guard let data = json["data"] as? [String: Any],
              let total = data["totalUsage"] as? [String: Any] else {
            throw UsageError.parseError("model-usage response")
        }

        let totalTokens = total["totalTokensUsage"] as? Int ?? 0
        let totalCalls = total["totalModelCallCount"] as? Int ?? 0
        let rawModels = total["modelSummaryList"] as? [[String: Any]] ?? []

        let sumTokens = rawModels.reduce(0) { $0 + ($1["totalTokens"] as? Int ?? 0) }

        let models = rawModels.map { m -> ModelUsage in
            let tokens = m["totalTokens"] as? Int ?? 0
            let pct = sumTokens > 0 ? Double(tokens) / Double(sumTokens) * 100 : 0
            let name = (m["modelName"] as? String ?? "?").replacingOccurrences(of: "GLM-", with: "")
            return ModelUsage(name: name, tokens: tokens, percentage: pct)
        }

        return ModelUsageResponse(totalTokens: totalTokens, totalCalls: totalCalls, models: models)
    }

    private func queryQuotaLimit(token: String) async throws -> QuotaResponse {
        let urlString = "\(baseURL)/api/monitor/usage/quota/limit"
        let json = try await request(urlString, token: token)
        guard let data = json["data"] as? [String: Any] else {
            throw UsageError.parseError("quota/limit response")
        }

        let level = data["level"] as? String ?? "N/A"
        let limits = data["limits"] as? [[String: Any]] ?? []

        var wm5h: Double = 0
        var wm7d: Double = 0
        var reset5h: Date?
        var reset7d: Date?
        var mcpUsed = 0
        var mcpCap = 0
        var mcpDetails: [MCPDetail] = []

        for lim in limits {
            let type = lim["type"] as? String ?? ""
            if type == "TOKENS_LIMIT" {
                let unit = lim["unit"] as? Int ?? 0
                let number = lim["number"] as? Int ?? 0
                let pct = lim["percentage"] as? Double ?? 0
                let resetTime = parseResetTime(lim["nextResetTime"])
                if unit == 3 && number == 5 {
                    wm5h = pct
                    reset5h = resetTime
                }
                if unit == 6 && number == 1 {
                    wm7d = pct
                    reset7d = resetTime
                }
            }
            if type == "TIME_LIMIT" {
                mcpUsed = lim["currentValue"] as? Int ?? 0
                mcpCap = lim["usage"] as? Int ?? 0
                let details = lim["usageDetails"] as? [[String: Any]] ?? []
                mcpDetails = details.map { d in
                    MCPDetail(code: d["modelCode"] as? String ?? "?", usage: d["usage"] as? Int ?? 0)
                }
            }
        }

        return QuotaResponse(level: level, wm5h: wm5h, wm7d: wm7d, reset5h: reset5h, reset7d: reset7d, mcpUsed: mcpUsed, mcpCap: mcpCap, mcpDetails: mcpDetails)
    }

    private func parseResetTime(_ raw: Any?) -> Date? {
        if let value = raw as? Double {
            return Date(timeIntervalSince1970: value / 1000)
        }
        if let value = raw as? Int {
            return Date(timeIntervalSince1970: Double(value) / 1000)
        }
        if let value = raw as? Int64 {
            return Date(timeIntervalSince1970: Double(value) / 1000)
        }
        if let value = raw as? String, let milliseconds = Double(value) {
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        return nil
    }

    private func request(_ urlString: String, token: String) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else {
            throw UsageError.apiError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UsageError.apiError("Not HTTP response")
        }
        guard http.statusCode == 200 else {
            throw UsageError.apiError("HTTP \(http.statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.parseError("Invalid JSON")
        }
        let code = json["code"] as? Int ?? 0
        guard code == 200 else {
            let msg = json["msg"] as? String ?? "Unknown"
            throw UsageError.apiError("\(code): \(msg)")
        }
        return json
    }
}

// MARK: - Internal Response Types

private struct ModelUsageResponse {
    let totalTokens: Int
    let totalCalls: Int
    let models: [ModelUsage]
}

private struct QuotaResponse {
    let level: String
    let wm5h: Double
    let wm7d: Double
    let reset5h: Date?
    let reset7d: Date?
    let mcpUsed: Int
    let mcpCap: Int
    let mcpDetails: [MCPDetail]
}