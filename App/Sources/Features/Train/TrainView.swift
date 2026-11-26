import AZModel
import AZStore
import SwiftUI

/// Train: this week's plan, today's session with Div's swaps marked, and the sessions still to come.
/// Design: design/source/src/Train.html
struct TrainView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment

    private var store: AZStore { environment.store }
    private var today: String { environment.today }

    var body: some View {
        let week = (try? store.week(today: today)) ?? []
        let ahead = (try? store.sessionsAhead(today: today)) ?? []
        let todaySession = try? store.todaySession(today: today)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LargeTitle(caption: caption(week), title: "This week")
                    Spacer()
                    IconButton(systemImage: "magnifyingglass", label: "Exercise library") { router.push(.swapExercise(nil)) }
                }
                WeekStrip(week).padding(.top, 16)
                if let todaySession {
                    todayCard(todaySession).padding(.top, 20)
                }
                let coming = ahead.filter { $0.day > today }
                SectionHeader(title: "Coming up").padding(.top, 26)
                if coming.isEmpty {
                    Text("Nothing else this week.").font(.az(15)).foregroundStyle(AZColor.muted).padding(.top, 8)
                }
                ForEach(coming, id: \.session.id) { session in
                    upcoming(session).padding(.top, 6)
                }
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// "3 of 4 done"
    private func caption(_ week: [WeekDay]) -> String {
        let planned = week.filter { $0.sessionName != nil }.count
        let done = week.filter { $0.state == .done }.count
        return planned == 0 ? "No sessions planned" : "\(done) of \(planned) done"
    }

    private func upcoming(_ session: SessionPreview) -> some View {
        let date = Day.date(session.day)
        return HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(date?.formatted(.dateTime.weekday(.abbreviated)).uppercased() ?? "").font(.az(11, .bold))
                    .foregroundStyle(AZColor.muted)
                Text(session.day.suffix(2).trimmingPrefix("0")).font(.az(16, .heavy)).monospacedDigit()
            }
            .frame(width: 48, height: 48)
            .background(AZColor.fill, in: .rect(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(session.session.name).font(.az(16, .bold))
                    if session.moved { DivMark(size: 16) }
                }
                Text(
                    session.moved
                        ? "Moved from \(session.session.weekdayName) · \(session.minutes) min"
                        : "\(session.lines.count) exercises · \(session.minutes) min"
                )
                .font(.az(14)).foregroundStyle(AZColor.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 64)
    }

    /// The header starts the workout; each line opens its exercise.
    private func todayCard(_ session: SessionPreview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                router.push(.workout)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Today · \(session.minutes) min").font(.az(14, .semibold)).foregroundStyle(AZColor.divInk)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill").font(.system(size: 11))
                            Text("Start")
                        }
                        .font(.az(14, .bold))
                        .foregroundStyle(AZColor.buttonInk)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(AZColor.button, in: .capsule)
                    }
                    Text(session.session.name).font(.az(30, .heavy)).tracking(-0.9)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(session.session.name)")
            VStack(spacing: 0) {
                ForEach(session.lines, id: \.exerciseID) { line in
                    Button {
                        router.push(.exercise(line.exerciseID))
                    } label: {
                        self.line(sets: line.prescription) {
                            HStack(spacing: 5) {
                                Text(line.name).lineLimit(1)
                                if let was = line.swappedFrom {
                                    DivMark(size: 16)
                                    WasValue(value: was).font(.az(13.5)).padding(.leading, 3).lineLimit(1)
                                }
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.az(14.5))
            .padding(.top, 10)
        }
        .padding(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AZColor.divTint, in: .rect(cornerRadius: 28, style: .continuous))
    }

    private func line<Name: View>(sets: String, @ViewBuilder _ name: () -> Name) -> some View {
        HStack {
            name()
            Spacer(minLength: 8)
            Text(sets).foregroundStyle(AZColor.divMuted).monospacedDigit()
        }
        .frame(height: 26)
    }
}

#Preview {
    NavigationStack { TrainView() }.environment(Router()).environment(AppEnvironment.preview())
}
