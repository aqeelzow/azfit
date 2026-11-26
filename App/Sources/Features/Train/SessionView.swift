import AZModel
import AZStore
import SwiftUI

/// One planned session this week: its day, its exercises, and a Start button that works on any day. A session done
/// early or late is logged today and ticks off the day it was planned for.
struct SessionView: View {
    let sessionID: UUID

    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        let today = environment.today
        let session = (try? environment.store.weekSessions(today: today))?.first { $0.session.id == sessionID }
        VStack(spacing: 0) {
            TopBar {
                BackButton()
            } center: {
                EmptyView()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            if let session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel(text: caption(session, today: today))
                        Text(session.session.name).font(.az(34, .heavy)).tracking(-0.85).padding(.top, 2)
                        if let note = note(session, today: today) {
                            Text(note).font(.az(14.5)).foregroundStyle(AZColor.muted).padding(.top, 6)
                        }
                        SectionHeader(title: "Exercises").padding(.top, 24)
                        HairlineStack {
                            ForEach(session.lines, id: \.exerciseID) { line in
                                Button {
                                    router.push(.exercise(line.exerciseID))
                                } label: {
                                    row(line)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, AZSpacing.gutter)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                PrimaryButton(
                    title: session.done ? "Do it again" : session.day == today ? "Start" : "Start it now",
                    trailingImage: "play.fill", style: session.done ? .soft : .dark
                ) {
                    router.push(.workout(sessionID))
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 12)
            } else {
                Text("This session isn't in your plan anymore.").font(.az(15)).foregroundStyle(AZColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AZSpacing.gutter).padding(.top, 16)
                Spacer()
            }
        }
        .azScreen()
    }

    /// "Today · 45 min", "Friday, Nov 27 · 45 min", "Done this week"
    private func caption(_ session: SessionPreview, today: String) -> String {
        if session.done { return "Done this week" }
        let day = session.day == today ? "Today" : AppEnvironment.caption(session.day)
        return "\(day) · \(session.minutes) min"
    }

    private func note(_ session: SessionPreview, today: String) -> String? {
        if session.done { return nil }
        let weekday = Day.date(session.day)?.formatted(.dateTime.weekday(.wide)) ?? "its day"
        if session.day > today { return "Starting it now logs it for today and ticks off \(weekday)." }
        if session.day < today { return "Planned for \(weekday). You can still do it today." }
        if session.moved { return "Div moved this here from \(session.session.weekdayName) for this week." }
        return nil
    }

    private func row(_ line: SessionPreview.Line) -> some View {
        HStack(spacing: 8) {
            Text(line.name).font(.az(16, .semibold)).lineLimit(1)
            if let was = line.swappedFrom {
                DivMark(size: 16)
                WasValue(value: was).font(.az(13.5)).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(line.prescription).font(.az(15)).foregroundStyle(AZColor.muted).monospacedDigit()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AZColor.faint)
        }
        .frame(minHeight: 56)
        .contentShape(.rect)
    }
}

#Preview {
    NavigationStack { SessionView(sessionID: UUID()) }.environment(Router()).environment(AppEnvironment.preview())
}
