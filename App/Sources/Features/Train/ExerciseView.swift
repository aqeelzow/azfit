import SwiftUI

/// One exercise: why Div swapped it in (undoable), muscles worked, how to, and a starting weight.
/// Design: design/source/src/Exercise.html
struct ExerciseView: View {
    @State private var isBack = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                BackButton()
            } center: {
                EmptyView()
            } trailing: {
                IconButton(systemImage: "ellipsis", label: "More") {}
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 16) {
                        PhotoTile(name: "ohp", size: 88, radius: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            SectionLabel(text: "Shoulders · Barbell")
                            Text(isBack ? "Overhead press" : "Landmine press").font(.az(28, .heavy)).tracking(-0.56)
                                .contentTransition(.opacity)
                            Text("3 × 10 in Push A").font(.az(14.5)).foregroundStyle(AZColor.muted)
                        }
                    }
                    .padding(.top, 16)

                    note.padding(.top, 22).animation(.snappy(duration: 0.22), value: isBack)

                    SectionHeader(title: "Muscles worked").padding(.top, 26)
                    HStack(spacing: 22) {
                        BodyFigure(side: .front, levels: "142001000").frame(width: 52, height: 134)
                            .accessibilityLabel("Front view, front delts and upper chest highlighted")
                        VStack(spacing: 0) {
                            HairlineStack {
                                muscle("Front delts", "Primary")
                                muscle("Upper chest", "Secondary")
                                muscle("Triceps", "Secondary")
                            }
                        }
                    }
                    .padding(.top, 10)

                    SectionHeader(title: "How to").padding(.top, 24)
                    VStack(alignment: .leading, spacing: 12) {
                        step(1, "Wedge one end of the bar into a corner.")
                        step(2, "Press up and forward to a straight arm.")
                        step(3, "Lower for two seconds, ribs down.")
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Start at 25 kg × 10").font(.az(15, .bold))
                        Text("Based on your overhead press, 50 kg × 8").font(.az(13.5)).foregroundStyle(AZColor.muted)
                    }
                    .monospacedDigit()
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(AZColor.fill, in: .rect(cornerRadius: 18, style: .continuous))
                    .padding(.top, 26)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .azScreen()
    }

    @ViewBuilder
    private var note: some View {
        if isBack {
            DivNote(
                title: "Overhead press is back", message: "Stop if the shoulder pinches. I'll check in after set 1.", tone: .settled,
                mood: .side,
                actionsOnRight: true
            ) {
                PillButton(title: "Use landmine") { isBack = false }
            }
            .transition(.opacity)
        } else {
            DivNote(
                title: "Swapped in by Div",
                message: "You said your shoulder felt tight on Tuesday. This angled press works the same muscles with less strain overhead."
            ) {
                PillButton(title: "Go back to overhead press", systemImage: "arrow.uturn.backward") { isBack = true }
            }
            .transition(.opacity)
        }
    }

    private func muscle(_ name: String, _ role: String) -> some View {
        HStack {
            Text(name).font(.az(15))
            Spacer()
            Text(role).font(.az(13.5)).foregroundStyle(AZColor.muted)
        }
        .frame(height: 42)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.az(13, .heavy))
                .frame(width: 24, height: 24)
                .background(AZColor.fill, in: .rect(cornerRadius: 8, style: .continuous))
                .padding(.top, -2)
            Text(text).font(.az(15)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack { ExerciseView() }
}
