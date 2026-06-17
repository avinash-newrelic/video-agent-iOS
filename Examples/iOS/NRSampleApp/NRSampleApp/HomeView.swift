import SwiftUI

struct HomeView: View {

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let featured = ContentCatalog.featured() {
                        HeroCardView(item: featured)
                            .padding(.horizontal, 16)
                    }

                    ForEach([ContentItem.Section.live, .vod], id: \.self) { section in
                        let items = ContentCatalog.items(in: section)
                        if !items.isEmpty {
                            SectionRow(title: section.displayName, items: items)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 8)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Watch")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        LogViewerView()
                    } label: {
                        Image(systemName: "doc.text")
                            .accessibilityLabel("Logs")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        AppLog.shared.log(.action, "Catalog", "open logs")
                    })
                }
            }
            #endif
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        .onAppear {
            AppLog.shared.log(.event, "App", "HomeView appeared",
                              ["catalog_size": ContentCatalog.items.count])
        }
    }
}

private struct SectionRow: View {
    let title: String
    let items: [ContentItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink {
                            PlayerView(item: item)
                        } label: {
                            CardView(item: item)
                        }
                        .buttonStyle(.plain)
                        #if os(iOS)
                        .simultaneousGesture(TapGesture().onEnded {
                            AppLog.shared.log(.action, "Catalog", "tap card",
                                              ["id": item.id, "title": item.title])
                        })
                        #endif
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct HeroCardView: View {
    let item: ContentItem

    var body: some View {
        NavigationLink {
            PlayerView(item: item)
        } label: {
            ZStack(alignment: .bottomLeading) {
                CardImage(item: item)
                    .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 240)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .center, endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .simultaneousGesture(TapGesture().onEnded {
            AppLog.shared.log(.action, "Catalog", "tap hero",
                              ["id": item.id, "title": item.title])
        })
        #endif
    }
}

#Preview {
    HomeView().preferredColorScheme(.dark)
}
