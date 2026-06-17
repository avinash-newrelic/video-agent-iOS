import SwiftUI

/// Read-only view of today's log file. Reload tail every second while visible.
struct LogViewerView: View {

    @State private var lines: [String] = []
    @State private var loadedAt: Date = .distantPast
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Logs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            reload()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                reload()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            Text(AppLog.shared.todayURL().lastPathComponent)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(lines.count) lines")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if lines.isEmpty {
                        Text("(no log entries yet)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                            .padding()
                    } else {
                        ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(color(for: line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .selectableTextOnIOS()
                                .padding(.horizontal, 12)
                                .id(idx)
                        }
                        Color.clear.frame(height: 8).id("bottom")
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: lines.count) { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private func reload() {
        let url = AppLog.shared.todayURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            lines = []
            return
        }
        let new = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        if new.count != lines.count { lines = new }
        loadedAt = Date()
    }

    private func color(for line: String) -> Color {
        if line.contains("[FAIL")  { return .red }
        if line.contains("[WARN")  { return .yellow }
        if line.contains("[ACTION") { return .cyan }
        if line.contains("[EVENT") { return .green }
        return .primary
    }
}

private extension View {
    @ViewBuilder
    func selectableTextOnIOS() -> some View {
        #if os(iOS)
        self.textSelection(.enabled)
        #else
        self
        #endif
    }
}

#Preview {
    NavigationView { LogViewerView() }.preferredColorScheme(.dark)
}
