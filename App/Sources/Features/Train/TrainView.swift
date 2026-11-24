import SwiftUI

/// Train: this week's plan, today's session with Div's swap marked, and the session Div moved.
/// Design: design/source/src/Train.html
struct TrainView: View {
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LargeTitle(caption: "Week 7 of 12 · 3 of 5 done", title: "This week")
                    Spacer()
                    IconButton(systemImage: "magnifyingglass", label: "Exercise library") { router.push(.swapExercise) }
                }
                WeekStrip().padding(.top, 16)
                todayCard.padding(.top, 20)
                SectionHeader(title: "Coming up").padding(.top, 26)
                HStack(spacing: 14) {
                    VStack(spacing: 1) {
                        Text("SUN").font(.az(11, .bold)).foregroundStyle(AZColor.muted)
                        Text("22").font(.az(16, .heavy)).monospacedDigit()
                    }
                    .frame(width: 48, height: 48)
                    .background(AZColor.fill, in: .rect(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text("Upper A").font(.az(16, .bold))
                            DivMark(size: 16)
                        }
                        Text("Moved from Friday · 55 min").font(.az(14)).foregroundStyle(AZColor.muted)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 64)
                .padding(.top, 6)
                DivNote(title: "Moved by Div", message: "You missed Friday. Sunday is free and rests your chest after today.") {
                    PillButton(title: "Undo", systemImage: "arrow.uturn.backward") {}
                    PillButton(title: "Skip this week") {}
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var todayCard: some View {
        Button {
            router.push(.workout)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Today · 52 min").font(.az(14, .semibold)).foregroundStyle(AZColor.divInk)
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
                Text("Push A").font(.az(30, .heavy)).tracking(-0.9).padding(.top, 2)
                VStack(spacing: 0) {
                    line(sets: "4 × 8") { Text("Bench press") }
                    line(sets: "3 × 10") { Text("Incline dumbbell press") }
                    line(sets: "3 × 10") {
                        HStack(spacing: 5) {
                            Text("Landmine press")
                            DivMark(size: 16)
                            WasValue(value: "Overhead press").font(.az(13.5)).padding(.leading, 3).lineLimit(1)
                        }
                    }
                    line(sets: "3 × 12") { Text("Cable fly, lateral raise, pushdown").foregroundStyle(AZColor.divMuted).lineLimit(1) }
                }
                .font(.az(14.5))
                .padding(.top, 10)
            }
            .padding(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AZColor.divTint, in: .rect(cornerRadius: 28, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
    NavigationStack { TrainView() }.environment(Router())
}
