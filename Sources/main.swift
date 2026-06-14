import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Prevent macOS automatic termination / App Nap
ProcessInfo.processInfo.disableAutomaticTermination("GLMUsageBar")
ProcessInfo.processInfo.disableSuddenTermination()
let _activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep], reason: "GLM Usage Monitor needs to stay alive for periodic refresh")

class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let service = UsageService()
    private var currentData: UsageData = .empty
    private var lastError: UsageError?
    private var isLoading = false
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure status item is visible
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.title = " GLM"
        
        updateStatusBarTitle()
        buildMenu()
        startAutoRefresh()
        Task { await refresh() }
    }

    // MARK: - Status Bar Title

    private func updateStatusBarTitle() {
        guard let button = statusItem.button else { return }

        if lastError != nil {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "GLM Error")
            button.title = ""
            return
        }

        let wm5h = Int(currentData.watermark5h)
        let wm7d = Int(currentData.watermark7d)
        let isRed = currentData.watermark5h > 80 || currentData.watermark7d > 80

        // Compact: icon + "5%/7%" only (no "GLM" prefix)
        button.imagePosition = .imageLeading
        button.image = NSImage(systemSymbolName: "speedometer", accessibilityDescription: "GLM Usage")
        button.image?.size = NSSize(width: 14, height: 14)

        let title = " \(wm5h)/\(wm7d)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: isRed ? NSColor.systemRed : NSColor.textColor
        ]
        button.attributedTitle = NSAttributedString(string: title, attributes: attrs)
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Header
        _ = addBoldItem(menu, title: "\u{1F52C} GLM Usage Monitor", fontSize: 14)

        menu.addItem(NSMenuItem.separator())

        // Plan level
        _ = addBoldItem(menu, title: "Plan \(currentData.planLevel.uppercased())", fontSize: 12)

        menu.addItem(NSMenuItem.separator())

        // Watermark section
        addSectionHeader(menu, title: "\u{1F4CA} \u{6C34}\u{4F4D}")

        let bar5h = coloredBar(currentData.watermark5h)
        addMenuItem(menu, title: "  5h   \(bar5h)  \(Int(currentData.watermark5h))%   \u{91CD}\u{7F6E}: \(formatResetTime(currentData.reset5h))")

        let bar7d = coloredBar(currentData.watermark7d)
        addMenuItem(menu, title: "  7d   \(bar7d)  \(Int(currentData.watermark7d))%   \u{91CD}\u{7F6E}: \(formatResetTime(currentData.reset7d))")

        menu.addItem(NSMenuItem.separator())

        // 24h section
        let tf24 = formatTokens(currentData.tokens24h)
        addSectionHeader(menu, title: "\u{1F4C8} 24h \u{7528}\u{91CF}  \(tf24)  \u{00B7}  \(currentData.calls24h) \u{6B21}\u{8C03}\u{7528}")

        for m in currentData.models24h.sorted(by: { $0.tokens > $1.tokens }) {
            addMenuItem(menu, title: "  \(m.name.padding(toLength: 10, withPad: " ", startingAt: 0)) \(m.displayTokens.padding(toLength: 8, withPad: " ", startingAt: 0)) \(String(format: "%5.1f%%", m.percentage))")
        }

        menu.addItem(NSMenuItem.separator())

        // MCP section
        let mcpPct = currentData.mcpCap > 0
            ? String(format: "%.1f%%", Double(currentData.mcpUsed) / Double(currentData.mcpCap) * 100)
            : "N/A"
        addSectionHeader(menu, title: "\u{1F527} MCP (\u{672C}\u{6708})  \(currentData.mcpUsed)/\(currentData.mcpCap)  \(mcpPct)")

        if !currentData.mcpDetails.isEmpty {
            let detail = currentData.mcpDetails
                .map { "\($0.code) \($0.usage)\u{6B21}" }
                .joined(separator: "  \u{00B7}  ")
            addMenuItem(menu, title: "  \(detail)")
        }

        menu.addItem(NSMenuItem.separator())

        // Error
        if let error = lastError {
            addMenuItem(menu, title: "\u{274C} \(error.localizedDescription)")
            menu.addItem(NSMenuItem.separator())
        }

        // Refresh
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        let timeStr = currentData.lastUpdated == .distantPast ? "--:--" : df.string(from: currentData.lastUpdated)
        let refreshTitle = isLoading ? "\u{23F3} \u{5237}\u{65B0}\u{4E2D}..." : "\u{1F504} \u{5237}\u{65B0}"
        let refreshItem = menu.addItem(withTitle: refreshTitle, action: #selector(refreshClicked), keyEquivalent: "r")
        refreshItem.isEnabled = !isLoading

        let timeItem = menu.addItem(withTitle: "\u{23F1} \u{6700}\u{540E}\u{66F4}\u{65B0}: \(timeStr)  \u{00B7}  \u{6BCF}30min\u{81EA}\u{52A8}\u{5237}\u{65B0}", action: nil, keyEquivalent: "")
        timeItem.isEnabled = false

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "\u{9000}\u{51FA} GLM Usage Monitor", action: #selector(quitClicked), keyEquivalent: "q")

        statusItem.menu = menu
    }

    // MARK: - Menu Helpers

    private func addBoldItem(_ menu: NSMenu, title: String, fontSize: CGFloat = 12) -> NSMenuItem {
        let item = NSMenuItem()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.textColor
        ]
        item.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        item.action = nil
        menu.addItem(item)
        return item
    }

    private func addSectionHeader(_ menu: NSMenu, title: String) {
        let item = NSMenuItem()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.textColor
        ]
        item.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        item.action = nil
        menu.addItem(item)
    }

    private func addMenuItem(_ menu: NSMenu, title: String) {
        let item = NSMenuItem()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.textColor
        ]
        item.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        item.action = nil
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func refreshClicked() {
        Task { await refresh() }
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }

    // MARK: - Refresh

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil
        buildMenu()

        do {
            currentData = try await service.fetchUsage()
            lastError = nil
        } catch let error as UsageError {
            lastError = error
        } catch {
            lastError = .apiError(error.localizedDescription)
        }

        isLoading = false
        updateStatusBarTitle()
        buildMenu()
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.refresh()
            }
        }
    }

    // MARK: - Format Helpers

    private func coloredBar(_ pct: Double, width: Int = 12) -> String {
        let filled = max(0, min(width, Int(round(pct / 100 * Double(width)))))
        return String(repeating: "\u{2588}", count: filled) + String(repeating: "\u{2591}", count: width - filled)
    }

    private func formatResetTime(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
        }
        return formatter.string(from: date)
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.0fK", Double(n) / 1_000)
        }
        return "\(n)"
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
