import SwiftUI

/// Eat: calories left against Div's target, macros as bars, Div's question about a missing meal, and today's meals.
/// Design: design/source/src/Eat.html
struct EatView: View {
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom) {
                    LargeTitle(caption: "Saturday, Nov 21", title: "Eat")
                    Spacer()
                    IconButton(systemImage: "target", label: "Calorie target") { router.push(.calorieTarget) }
                }
                summary.padding(.top, 16)
                DivNote(
                    title: "Did Thursday's dinner slip through?",
                    message: "You logged 1,180 kcal, about half your usual, and your weight didn't move Friday.", tone: .settled
                ) {
                    PillButton(title: "Add it", style: .dark) { router.present(.snap) }
                    PillButton(title: "No, that's right") {}
                }
                .padding(.top, 16)
                HairlineStack {
                    meal("yogurt", "Greek yogurt", "Breakfast · 8:05", 380)
                    meal("salmon", "Salmon power bowl", "Lunch · 1:12 · estimate ±18%", 640)
                    meal("fruit", "Fruit bowl", "Snack · 4:30", 220)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, AZSpacing.gutter)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("1,110").font(.az(52, .heavy)).tracking(-2).monospacedDigit()
            Button {
                router.push(.calorieTarget)
            } label: {
                HStack(spacing: 4) {
                    Text("kcal left of").foregroundStyle(AZColor.divMuted)
                    Text("2,350").fontWeight(.bold).monospacedDigit()
                    DivMark().padding(.leading, 1)
                }
                .font(.az(15))
            }
            .buttonStyle(.plain)
            GeometryReader { geo in
                HStack(spacing: 3) {
                    Capsule().fill(AZColor.accent).frame(width: (geo.size.width - 3) * 0.53)
                    Capsule().fill(AZColor.card)
                }
            }
            .frame(height: 10)
            .padding(.top, 16)
            Spacer(minLength: 16)
            HStack(spacing: 18) {
                macro("Protein", 112, of: 165, color: AZColor.accent)
                macro("Carbs", 128, of: 250, color: AZColor.carbs)
                macro("Fat", 41, of: 75, color: AZColor.fat)
            }
        }
        .padding(EdgeInsets(top: 22, leading: 22, bottom: 20, trailing: 22))
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 234)
        .background(AZColor.divTint, in: .rect(cornerRadius: 32, style: .continuous))
    }

    private func macro(_ name: String, _ value: Int, of target: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.az(13, .semibold)).foregroundStyle(AZColor.divMuted)
            HStack(spacing: 0) {
                Text("\(value)").fontWeight(.heavy)
                Text("/\(target)g").fontWeight(.medium).foregroundStyle(AZColor.divMuted)
            }
            .font(.az(16))
            .monospacedDigit()
            MeterBar(value: Double(value) / Double(target), color: color, track: AZColor.card, height: 5)
        }
        .frame(maxWidth: .infinity)
    }

    private func meal(_ photo: String, _ name: String, _ detail: String, _ kcal: Int) -> some View {
        Button {
            router.push(.meal)
        } label: {
            HStack(spacing: 14) {
                PhotoTile(name: photo)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.az(16, .bold))
                    Text(detail).font(.az(14)).foregroundStyle(AZColor.muted)
                }
                Spacer(minLength: 0)
                Text("\(kcal)").font(.az(16, .bold)).monospacedDigit()
            }
            .frame(minHeight: 64)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { EatView() }.environment(Router())
}
