import SwiftUI

/// Home: the week, today's session, what Div changed, and food and weight at a glance.
/// Design: design/source/src/Home.html
struct HomeView: View {
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LargeTitle(caption: "Saturday, Nov 21", title: "Morning, Alex")
                    Spacer()
                    Button {
                        router.push(.memory)
                    } label: {
                        PhotoTile(name: "avatar", size: 44, radius: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile")
                }
                Button {
                    router.show(.train)
                } label: {
                    WeekStrip()
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                todayCard.padding(.top, 20)
                divChanges.padding(.top, 16)
                HStack(spacing: 12) {
                    foodTile
                    weightTile
                }
                .padding(.top, 14)
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
                Text("Today · 52 min").font(.az(14, .semibold)).foregroundStyle(AZColor.divInk)
                Text("Push A").font(.az(40, .heavy)).tracking(-1.4)
                VStack(spacing: 0) {
                    exerciseLine("Bench press", "4 × 8")
                    exerciseLine("Incline dumbbell press", "3 × 10")
                    exerciseLine("Landmine press", "3 × 10", changedByDiv: true)
                    HStack {
                        Text("+3 more").foregroundStyle(AZColor.divMuted)
                        Spacer()
                    }
                    .frame(height: 26)
                }
                .font(.az(14.5))
                .padding(.top, 14)
                Spacer(minLength: 16)
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 13))
                    Text("Start")
                }
                .font(.az(16.5, .bold))
                .foregroundStyle(AZColor.buttonInk)
                .frame(width: 128, height: 50)
                .background(AZColor.button, in: .capsule)
            }
            .padding(EdgeInsets(top: 24, leading: 24, bottom: 22, trailing: 24))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 288)
            .background(AZColor.divTint, in: .rect(cornerRadius: 32, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func exerciseLine(_ name: String, _ sets: String, changedByDiv: Bool = false) -> some View {
        HStack {
            HStack(spacing: 5) {
                Text(name)
                if changedByDiv { DivMark(size: 16) }
            }
            Spacer()
            Text(sets).foregroundStyle(AZColor.divMuted).monospacedDigit()
        }
        .frame(height: 26)
    }

    private var divChanges: some View {
        Button {
            router.push(.divLog)
        } label: {
            HStack(spacing: 12) {
                DivAvatar(size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Div made 3 changes this week").font(.az(15, .bold))
                    Text("And has 1 question for you").font(.az(13.5)).foregroundStyle(AZColor.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(AZColor.faint)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(height: 68)
            .background(AZColor.fill, in: .rect(cornerRadius: 24, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var foodTile: some View {
        Button {
            router.show(.eat)
        } label: {
            tile {
                SectionLabel(text: "Food")
                Spacer(minLength: 0)
                Text("1,110").font(.az(26, .heavy)).tracking(-0.5).monospacedDigit()
                Text("kcal left").font(.az(13.5)).foregroundStyle(AZColor.muted).padding(.bottom, 8)
                MeterBar(value: 0.53, height: 6)
            }
        }
        .buttonStyle(.plain)
    }

    private var weightTile: some View {
        Button {
            router.push(.progress)
        } label: {
            tile {
                HStack {
                    SectionLabel(text: "Weight")
                    Spacer()
                    SVGShape(data: "M2 4C10 4 14 9 20 10S30 9 36 14S48 18 56 21", viewBox: CGRect(x: 0, y: 0, width: 58, height: 24))
                        .stroke(AZColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 58, height: 24)
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("82.2").font(.az(26, .heavy)).tracking(-0.5)
                    Text(" kg").font(.az(15, .semibold)).foregroundStyle(AZColor.muted)
                }
                .monospacedDigit()
                Text("-2.1 kg in 3 weeks").font(.az(13.5)).foregroundStyle(AZColor.muted)
            }
        }
        .buttonStyle(.plain)
    }

    private func tile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 112)
            .background(AZColor.fill, in: .rect(cornerRadius: 26, style: .continuous))
            .contentShape(.rect)
    }
}

#Preview {
    MainView()
}
