import AZModel
import AZStore
import SwiftUI

/// Train: the week's plan. Tapping a day in the strip shows that day's session (or that it's a rest day) under it;
/// today is picked to start with. Swiping the strip goes week to week, back to the week the person joined.
/// Design: design/source/src/Train.html
struct TrainView: View {
    @Environment(Router.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var picked: String?
    /// Weeks from this one: -1 is last week.
    @State private var shift = 0
    /// The way the last swipe went, so the new week slides in from the right side.
    @State private var forward = true
    /// When a horizontal drag last moved, so the tap a swipe ends with doesn't also open what's under it.
    @State private var swipedAt = Date.distantPast

    /// The furthest ahead you can look.
    private static let weeksAhead = 8

    private var store: AZStore { environment.store }
    private var today: String { environment.today }

    var body: some View {
        let weekOf = Day.adding(7 * shift, to: today)
        let thisWeek = shift == 0
        let week = (try? store.week(today: today, weekOf: weekOf)) ?? []
        let sessions = (try? store.weekSessions(today: today, weekOf: weekOf)) ?? []
        let selected = picked.flatMap { day in week.contains { $0.day == day } ? day : nil } ?? (thisWeek ? today : week.first?.day)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LargeTitle(caption: caption(week), title: title(week))
                    Spacer()
                    if !thisWeek {
                        PillButton(title: "This week", style: .fill, height: 44) { go(to: 0) }
                    }
                    IconButton(systemImage: "magnifyingglass", label: "Exercise library") { router.push(.swapExercise(nil)) }
                }
                VStack(alignment: .leading, spacing: 0) {
                    WeekStrip(week, selected: selected) { day in
                        if !justSwiped { withAnimation(.snappy(duration: 0.2)) { picked = day.day } }
                    }
                    .padding(.top, 16)
                    if let day = week.first(where: { $0.day == selected }) {
                        dayCard(day, session: sessions.first { $0.session.id == day.sessionID }, thisWeek: thisWeek)
                            .padding(.top, 20)
                    }
                }
                .id(weekOf)
                .transition(.push(from: forward ? .trailing : .leading))
                .contentShape(.rect)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 24)
                        .onChanged { drag in
                            if abs(drag.translation.width) > 12 { swipedAt = .now }
                        }
                        .onEnded { drag in
                            let x = drag.translation.width
                            if abs(x) > 12 { swipedAt = .now }
                            guard abs(x) > 50, abs(x) > abs(drag.translation.height) * 1.5 else { return }
                            go(to: shift + (x < 0 ? 1 : -1))
                        }
                )
                .accessibilityAction(named: "Next week") { go(to: shift + 1) }
                .accessibilityAction(named: "Previous week") { go(to: shift - 1) }
                if thisWeek {
                    thisWeekLists(sessions)
                }
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear(perform: takeTrainDay)
        .onChange(of: router.trainDay) { takeTrainDay() }
    }

    /// Picks the day tapped on Home, in this week.
    private func takeTrainDay() {
        guard let day = router.trainDay else { return }
        router.trainDay = nil
        shift = 0
        picked = day
    }

    /// The sessions not done yet this week: earlier ones still to catch up on, then the ones coming.
    @ViewBuilder
    private func thisWeekLists(_ sessions: [SessionPreview]) -> some View {
        let earlier = sessions.filter { $0.day < today && !$0.done }
        if !earlier.isEmpty {
            SectionHeader(title: "Earlier this week").padding(.top, 26)
            ForEach(earlier, id: \.session.id) { session in
                upcoming(session).padding(.top, 6)
            }
        }
        let coming = sessions.filter { $0.day > today }
        SectionHeader(title: "Coming up").padding(.top, 26)
        if coming.isEmpty {
            Text("Nothing else this week.").font(.az(15)).foregroundStyle(AZColor.muted).padding(.top, 8)
        }
        ForEach(coming, id: \.session.id) { session in
            upcoming(session).padding(.top, 6)
        }
    }

    private var justSwiped: Bool { Date.now.timeIntervalSince(swipedAt) < 0.35 }

    /// Opens a screen from the swipe area, unless the touch was a swipe.
    private func open(_ route: Router.Route) {
        if !justSwiped { router.push(route) }
    }

    /// The earliest week you can swipe back to: the one the person joined in.
    private var earliestShift: Int {
        guard let joined = environment.profile.map({ Day.string($0.createdAt) }) else { return 0 }
        let first = AZStore.monday(of: joined)
        var weeks = 0
        while Day.adding(-7 * (weeks + 1), to: AZStore.monday(of: today)) >= first { weeks += 1 }
        return -weeks
    }

    /// Slides to another week, keeping the same weekday picked.
    private func go(to newShift: Int) {
        let clamped = min(max(newShift, earliestShift), Self.weeksAhead)
        guard clamped != shift else { return }
        forward = clamped > shift
        let selected = picked ?? today
        withAnimation(.snappy(duration: 0.3)) {
            picked = clamped == 0 ? nil : Day.adding(7 * (clamped - shift), to: selected)
            shift = clamped
        }
    }

    /// "This week", "Last week", "Next week", or "Dec 7 - 13".
    private func title(_ week: [WeekDay]) -> String {
        switch shift {
        case 0: return "This week"
        case -1: return "Last week"
        case 1: return "Next week"
        default:
            guard let first = week.first, let last = week.last, let start = Day.date(first.day) else { return "Week" }
            return "\(start.formatted(.dateTime.month(.abbreviated).day())) - \(last.date)"
        }
    }

    /// "3 of 4 done"
    private func caption(_ week: [WeekDay]) -> String {
        let planned = week.filter { $0.sessionName != nil }.count
        let done = week.filter { $0.state == .done }.count
        return planned == 0 ? "No sessions planned" : "\(done) of \(planned) done"
    }

    /// A session row; tapping it shows its exercises and a Start button.
    private func upcoming(_ session: SessionPreview) -> some View {
        let date = Day.date(session.day)
        return Button {
            router.push(.session(session.session.id))
        } label: {
            sessionRow(session, date: date)
        }
        .buttonStyle(.plain)
    }

    private func sessionRow(_ session: SessionPreview, date: Date?) -> some View {
        HStack(spacing: 14) {
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
                Text(detail(session)).font(.az(14)).foregroundStyle(AZColor.muted)
            }
            Spacer(minLength: 0)
            if session.done {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(AZColor.accent)
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AZColor.faint)
        }
        .frame(minHeight: 64)
        .contentShape(.rect)
    }

    private func detail(_ session: SessionPreview) -> String {
        if session.done { return "Done early · \(session.lines.count) exercises" }
        if session.moved { return "Moved from \(session.session.weekdayName) · \(session.minutes) min" }
        return "\(session.lines.count) exercises · \(session.minutes) min"
    }

    /// The picked day: today's session to start, another day's session to open, or a rest day.
    @ViewBuilder
    private func dayCard(_ day: WeekDay, session: SessionPreview?, thisWeek: Bool) -> some View {
        if let session, day.day == today, !session.done {
            todayCard(session)
        } else if let session {
            plannedCard(session, day: day, openable: thisWeek)
        } else {
            restCard(day)
        }
    }

    private func dayName(_ day: String) -> String {
        day == today ? "Today" : AppEnvironment.caption(day)
    }

    /// A session on the picked day. Only this week's open to start; other weeks show the plan and how it went.
    @ViewBuilder
    private func plannedCard(_ session: SessionPreview, day: WeekDay, openable: Bool) -> some View {
        if openable {
            Button {
                open(.session(session.session.id))
            } label: {
                plannedCardBody(session, day: day, openable: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(session.session.name), \(dayName(session.day)), \(status(session, day: day))")
        } else {
            plannedCardBody(session, day: day, openable: false)
                .accessibilityElement(children: .combine)
        }
    }

    private func plannedCardBody(_ session: SessionPreview, day: WeekDay, openable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(dayName(session.day)) · \(status(session, day: day))")
                    .font(.az(14, .semibold)).foregroundStyle(AZColor.divInk)
                Spacer()
                if openable {
                    HStack(spacing: 6) {
                        Text(session.done ? "See it" : "Open")
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    }
                    .font(.az(14, .bold))
                    .foregroundStyle(AZColor.buttonInk)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(AZColor.button, in: .capsule)
                }
            }
            .frame(minHeight: 36)
            HStack(spacing: 8) {
                Text(session.session.name).font(.az(30, .heavy)).tracking(-0.9)
                if session.done {
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .heavy)).foregroundStyle(AZColor.accent)
                }
            }
            VStack(spacing: 0) {
                ForEach(session.lines.prefix(4), id: \.exerciseID) { line in
                    self.line(sets: line.prescription) { Text(line.name).lineLimit(1) }
                }
                if session.lines.count > 4 {
                    HStack {
                        Text("+\(session.lines.count - 4) more").foregroundStyle(AZColor.divMuted)
                        Spacer()
                    }
                    .frame(height: 26)
                }
            }
            .font(.az(14.5))
            .padding(.top, 10)
        }
        .padding(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AZColor.divTint, in: .rect(cornerRadius: 28, style: .continuous))
        .contentShape(.rect)
    }

    /// "Done", "Missed", "Not done" for days gone, else the length.
    private func status(_ session: SessionPreview, day: WeekDay) -> String {
        if session.done { return "Done" }
        if day.state == .missed { return "Missed" }
        if day.day < today { return "Not done" }
        return "\(session.minutes) min"
    }

    private func restCard(_ day: WeekDay) -> some View {
        let worked = day.state == .done
        return VStack(alignment: .leading, spacing: 4) {
            Text(dayName(day.day)).font(.az(14, .semibold)).foregroundStyle(AZColor.muted)
            Text(worked ? "Trained" : "Rest day").font(.az(30, .heavy)).tracking(-0.9)
            Text(worked ? "A workout was logged this day." : "No workout planned. Pick a day with a bar under it.")
                .font(.az(14.5)).foregroundStyle(AZColor.muted)
        }
        .padding(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AZColor.fill, in: .rect(cornerRadius: 28, style: .continuous))
    }

    /// The header starts the workout; each line opens its exercise.
    private func todayCard(_ session: SessionPreview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                open(.workout(session.session.id))
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
                        open(.exercise(line.exerciseID))
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
