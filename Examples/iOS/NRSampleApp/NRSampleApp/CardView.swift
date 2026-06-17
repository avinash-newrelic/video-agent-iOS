import SwiftUI

struct CardView: View {
    let item: ContentItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardImage(item: item)
                .frame(width: 280, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    if item.isLive { LiveBadge().padding(8) }
                }
                .overlay(alignment: .bottomTrailing) {
                    if let secs = item.durationSecs {
                        DurationBadge(seconds: secs).padding(8)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }
            .frame(maxWidth: 280, alignment: .leading)
        }
    }
}

struct CardImage: View {
    let item: ContentItem

    var body: some View {
        Group {
            if let url = item.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:           placeholder
                    case .success(let i):  i.resizable().scaledToFill()
                    case .failure:         placeholder
                    @unknown default:      placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: gradientFor(id: item.id),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: item.isLive ? "dot.radiowaves.left.and.right" : "play.rectangle.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    /// Stable gradient per id so cards keep the same color between launches.
    private func gradientFor(id: String) -> [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.20, green: 0.10, blue: 0.45), Color(red: 0.45, green: 0.15, blue: 0.55)],
            [Color(red: 0.05, green: 0.30, blue: 0.45), Color(red: 0.10, green: 0.55, blue: 0.65)],
            [Color(red: 0.45, green: 0.15, blue: 0.20), Color(red: 0.65, green: 0.30, blue: 0.20)],
            [Color(red: 0.10, green: 0.40, blue: 0.30), Color(red: 0.20, green: 0.60, blue: 0.45)],
            [Color(red: 0.30, green: 0.20, blue: 0.10), Color(red: 0.55, green: 0.40, blue: 0.20)],
        ]
        let bucket = abs(id.hashValue) % palettes.count
        return palettes[bucket]
    }
}

private struct LiveBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(.red).frame(width: 6, height: 6)
            Text("LIVE")
                .font(.caption2.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.7))
        .clipShape(Capsule())
    }
}

private struct DurationBadge: View {
    let seconds: Int

    var body: some View {
        Text(format(seconds))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.7))
            .clipShape(Capsule())
    }

    private func format(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CardView(item: ContentCatalog.items[1])
    }
    .preferredColorScheme(.dark)
}
