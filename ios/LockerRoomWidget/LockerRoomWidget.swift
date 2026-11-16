import WidgetKit
import SwiftUI

private let appGroupId = "group.com.makeshiftlabs.sharks_ice_locker_widget"

struct WidgetGameItem: Codable, Hashable {
    let myTeam: String
    let isHome: Bool
    let myLockerRoom: String
    let startTime: String

    var jerseyLabel: String {
        isHome ? "White" : "Dark"
    }
}

struct LockerRoomEntry: TimelineEntry {
    let date: Date
    let games: [WidgetGameItem]
}

struct LockerRoomProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockerRoomEntry {
        LockerRoomEntry(
            date: Date(),
            games: [
                WidgetGameItem(
                    myTeam: "Choking Hazards",
                    isHome: true,
                    myLockerRoom: "W4",
                    startTime: "7:45 PM"
                )
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LockerRoomEntry) -> Void) {
        completion(loadEntryFromSharedDefaults())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockerRoomEntry>) -> Void) {
        let entry = loadEntryFromSharedDefaults()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntryFromSharedDefaults() -> LockerRoomEntry {
        let sharedDefaults = UserDefaults(suiteName: appGroupId)
        let rawJson = sharedDefaults?.string(forKey: "user_games_json") ?? "[]"

        var decodedGames: [WidgetGameItem] = []
        if let data = rawJson.data(using: .utf8),
           let parsed = try? JSONDecoder().decode([WidgetGameItem].self, from: data) {
            decodedGames = parsed
        }

        return LockerRoomEntry(date: Date(), games: decodedGames)
    }
}

private var widgetGradientBackground: some View {
    LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.0, green: 0.18, blue: 0.21),
            Color(red: 0.0, green: 0.43, blue: 0.47)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    @ViewBuilder
    func applyWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                widgetGradientBackground
            }
        } else {
            ZStack {
                widgetGradientBackground
                self
            }
        }
    }
}

struct LockerRoomWidgetEntryView: View {
    var entry: LockerRoomProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if entry.games.isEmpty {
                VStack(spacing: 6) {
                    Text("LR —")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(Color(red: 1.0, green: 0.72, blue: 0.01))
                    Text("No Games Today")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(14)
            } else if family == .systemSmall {
                smallGamesView(games: entry.games)
            } else if family == .systemMedium {
                listGamesView(games: Array(entry.games.prefix(3)), compact: entry.games.count > 2)
            } else {
                listGamesView(games: Array(entry.games.prefix(6)), compact: false)
            }
        }
        .applyWidgetBackground()
    }

    /// Little jersey icon + "White" or "Dark" badge
    private func jerseyBadge(isWhite: Bool, compact: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "tshirt.fill")
                .font(.system(size: compact ? 9 : 11, weight: .bold))
                .foregroundColor(isWhite ? Color(red: 0.06, green: 0.09, blue: 0.16) : .white)
            Text(isWhite ? "White" : "Dark")
                .font(.system(size: compact ? 10 : 11, weight: .heavy))
                .foregroundColor(isWhite ? Color(red: 0.06, green: 0.09, blue: 0.16) : .white)
        }
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 2 : 4)
        .background(isWhite ? Color.white : Color(red: 0.12, green: 0.16, blue: 0.23))
        .cornerRadius(7)
    }

    private func smallGamesView(games: [WidgetGameItem]) -> some View {
        let game = games[0]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                // 1. Locker Room (e.g. W4, O2, B1)
                VStack(spacing: 0) {
                    Text("LR")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color(red: 0.0, green: 0.18, blue: 0.21))
                    Text(game.myLockerRoom)
                        .font(.system(size: 18, weight: .black))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .foregroundColor(Color(red: 0.0, green: 0.18, blue: 0.21))
                }
                .frame(width: 48, height: 42)
                .background(Color(red: 1.0, green: 0.72, blue: 0.01))
                .cornerRadius(10)

                Spacer()

                // 2. Jersey with icon
                jerseyBadge(isWhite: game.isHome, compact: true)
            }

            // 3. Time
            Text(game.startTime)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(Color(red: 1.0, green: 0.72, blue: 0.01))

            // 4. Team Name
            Text(game.myTeam)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            if games.count > 1 {
                Text("+\(games.count - 1) more game\(games.count > 2 ? "s" : "")")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
    }

    private func listGamesView(games: [WidgetGameItem], compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            ForEach(games, id: \.self) { game in
                HStack(spacing: 10) {
                    // 1. Locker Room (e.g. W4, O2, B1)
                    VStack(spacing: 0) {
                        Text("LR")
                            .font(.system(size: compact ? 8 : 9, weight: .black))
                            .foregroundColor(Color(red: 0.0, green: 0.18, blue: 0.21))
                        Text(game.myLockerRoom)
                            .font(.system(size: compact ? 15 : 18, weight: .black))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .foregroundColor(Color(red: 0.0, green: 0.18, blue: 0.21))
                    }
                    .frame(width: compact ? 44 : 52, height: compact ? 34 : 44)
                    .background(Color(red: 1.0, green: 0.72, blue: 0.01))
                    .cornerRadius(9)

                    // 2. Time + 3. Team Name
                    VStack(alignment: .leading, spacing: 1) {
                        Text(game.startTime)
                            .font(.system(size: compact ? 11 : 12, weight: .heavy))
                            .foregroundColor(Color(red: 1.0, green: 0.72, blue: 0.01))
                        Text(game.myTeam)
                            .font(.system(size: compact ? 13 : 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    // 4. Jersey with icon
                    jerseyBadge(isWhite: game.isHome, compact: compact)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(compact ? 11 : 14)
    }
}

extension WidgetConfiguration {
    func disableContentMarginsIfAvailable() -> some WidgetConfiguration {
        if #available(iOSApplicationExtension 17.0, *) {
            return self.contentMarginsDisabled()
        } else {
            return self
        }
    }
}

@main
struct LockerRoomWidget: Widget {
    let kind: String = "LockerRoomWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockerRoomProvider()) { entry in
            LockerRoomWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Which Room?")
        .description("Shows your game time, team name, locker room, and jersey color.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .disableContentMarginsIfAvailable()
    }
}
