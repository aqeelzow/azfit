import SwiftUI

/// The live session. Div lowered set 3 after you missed reps on set 2; "Keep 8 reps" undoes it and the note turns
/// neutral. Design: design/source/src/Workout.html
struct WorkoutView: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var kept = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                IconButton(systemImage: "chevron.down", label: "Minimize") { dismiss() }
            } center: {
                VStack(spacing: 0) {
                    Text("Push A").font(.az(17, .heavy))
                    Text("32:14").font(.az(14)).foregroundStyle(AZColor.muted).monospacedDigit()
                }
            } trailing: {
                PillButton(title: "Finish", style: .accent, height: 44) { router.push(.workoutDone) }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            MeterBar(value: 0.6, height: 6)
                            ForEach(0..<5, id: \.self) { _ in MeterBar(value: 0, height: 6) }
                        }
                        Text("3 of 17 sets").font(.az(13.5, .semibold)).foregroundStyle(AZColor.muted).monospacedDigit()
                    }
                    .padding(.top, 18)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exercise 1 of 6").font(.az(13, .bold)).foregroundStyle(AZColor.accent)
                            Text("Bench press").font(.az(28, .heavy)).tracking(-0.56)
                            Text("Chest, triceps · rest 2:30").font(.az(14.5)).foregroundStyle(AZColor.muted)
                        }
                        Spacer()
                        PillButton(title: "Swap", systemImage: "arrow.left.arrow.right", style: .fill, height: 36) {
                            router.push(.swapExercise)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.top, 20)

                    setTable.padding(.horizontal, -10).padding(.top, 20)

                    note.padding(.top, 14).animation(.snappy(duration: 0.22), value: kept)

                    SectionLabel(text: "Up next").padding(.top, 22)
                    Button {
                        router.push(.exercise)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 5) {
                                    Text("Landmine press").font(.az(16, .bold))
                                    DivMark(size: 16)
                                }
                                Text("Swapped in for overhead press · 3 × 10").font(.az(14)).foregroundStyle(AZColor.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(AZColor.faint)
                        }
                        .frame(minHeight: 56)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .bottom) { restBar }
        .azScreen()
    }

    // MARK: Sets

    private var setTable: some View {
        VStack(spacing: 4) {
            SetRow(set: "Set", previous: "Previous", target: Text("Target"), kg: "kg", reps: "Reps", state: .header)
            SetRow(set: "1", previous: "80 × 8", target: Text("82.5 × 8"), kg: "82.5", reps: "8", state: .done)
            SetRow(set: "2", previous: "80 × 8", target: Text("82.5 × 8"), kg: "82.5", reps: "6", state: .done, missedReps: true)
            SetRow(
                set: "3", previous: "80 × 8",
                target: kept ? Text("82.5 × 8") : Text("82.5 × 6"),
                kg: "82.5", reps: kept ? "8" : "6", state: .current, changedByDiv: !kept)
        }
    }

    @ViewBuilder
    private var note: some View {
        if kept {
            DivNote(
                title: "Back to 8. Your call.", message: "If set 3 stalls early, stop at 6.", tone: .settled, mood: .side,
                actionsOnRight: true
            ) {
                PillButton(title: "Use 6") { kept = false }
            }
            .transition(.opacity)
        } else {
            DivNote(
                title: "I lowered set 3 to 6 reps",
                message: "You got 6 on set 2. Matching it keeps your form clean and still counts as a hard set."
            ) {
                PillButton(title: "Keep 8 reps", systemImage: "arrow.uturn.backward") { kept = true }
            }
            .transition(.opacity)
        }
    }

    // MARK: Rest timer

    private var restBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Rest").font(.az(13)).foregroundStyle(.white.opacity(0.62))
                Text("1:34").font(.az(24, .heavy)).monospacedDigit()
            }
            Spacer()
            Button("+15s") {}
                .font(.az(14, .bold))
                .padding(.horizontal, 18).frame(height: 48)
                .background(AZColor.rest2, in: .rect(cornerRadius: 16, style: .continuous))
            Button("Skip") {}
                .font(.az(14, .bold))
                .foregroundStyle(AZColor.Camera.tagInk)
                .padding(.horizontal, 20).frame(height: 48)
                .background(.white, in: .rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.leading, 22)
        .padding(.trailing, 10)
        .frame(height: 72)
        .background(alignment: .topLeading) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    AZColor.rest
                    AZColor.accent.frame(width: geo.size.width * 0.63, height: 4)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .environment(\.colorScheme, .light)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

/// One row of the set table: set number, last time, today's target, weight, reps and the check.
private struct SetRow: View {
    enum State { case header, done, current }

    var set: String
    var previous: String
    var target: Text
    var kg: String
    var reps: String
    var state: State
    var missedReps = false
    var changedByDiv = false

    var body: some View {
        HStack(spacing: 8) {
            Text(set).fontWeight(state == .header ? .semibold : .bold).frame(width: 28, alignment: .leading)
            Text(previous).foregroundStyle(AZColor.faint).frame(maxWidth: .infinity, alignment: .leading)
            targetView.frame(maxWidth: .infinity, alignment: .leading)
            field(kg).frame(width: 60)
            field(reps, color: missedReps ? AZColor.accent : (state == .current ? AZColor.ghost : AZColor.ink)).frame(width: 50)
            check.frame(width: 36)
        }
        .font(state == .header ? .az(13, .semibold) : .az(15.5))
        .foregroundStyle(state == .header ? AZColor.faint : AZColor.ink)
        .monospacedDigit()
        .padding(.horizontal, 10)
        .frame(height: state == .header ? 28 : 52)
        .background(state == .current ? AZColor.fill : .clear, in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var targetView: some View {
        if changedByDiv {
            target.fontWeight(.bold).foregroundStyle(AZColor.divInk)
                .padding(.horizontal, 7).frame(height: 28)
                .background(AZColor.divTint, in: .rect(cornerRadius: 9, style: .continuous))
                .padding(.leading, -7)
                .fixedSize()
        } else {
            target.foregroundStyle(state == .header ? AZColor.faint : AZColor.muted)
        }
    }

    @ViewBuilder
    private func field(_ value: String, color: Color = AZColor.ink) -> some View {
        if state == .header {
            Text(value).frame(maxWidth: .infinity)
        } else {
            Text(value)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(state == .current ? AZColor.card : AZColor.fill, in: .rect(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var check: some View {
        switch state {
        case .header:
            Color.clear.frame(height: 1)
        case .done:
            Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 34, height: 34).background(AZColor.accent, in: .rect(cornerRadius: 12, style: .continuous))
        case .current:
            Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(AZColor.ghost)
                .frame(width: 34, height: 34).background(AZColor.card, in: .rect(cornerRadius: 12, style: .continuous))
        }
    }
}

#Preview {
    NavigationStack { WorkoutView() }.environment(Router())
}
