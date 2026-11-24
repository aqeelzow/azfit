import SwiftUI

/// Swap an exercise: Div's picks for your situation on top, then the full list for the muscle.
/// Design: design/source/src/Library.html
struct SwapExerciseView: View {
    @Environment(Router.self) private var router
    @State private var filter = "Shoulders"

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Swap exercise") {
                BackButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold))
                        Text("Search 412 exercises").font(.az(15.5))
                        Spacer()
                    }
                    .foregroundStyle(AZColor.muted)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(AZColor.fill, in: .rect(cornerRadius: 16, style: .continuous))

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(["All", "Shoulders", "Chest", "Arms", "Back"], id: \.self) { name in
                                Chip(title: name, isOn: filter == name) { filter = name }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .padding(.top, 12)

                    HStack(alignment: .top, spacing: 10) {
                        DivAvatar(size: 28)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Div's picks").font(.az(17, .heavy))
                            Text("Shoulder-friendly, since you said it felt tight Tuesday").font(.az(13.5)).foregroundStyle(AZColor.muted)
                        }
                    }
                    .padding(.top, 28)

                    HairlineStack {
                        exercise("ohp", "Landmine press", "Barbell · Front delts", changedByDiv: true, tag: "In your plan")
                        exercise("woman-gym", "Half-kneeling dumbbell press", "Dumbbell · Front delts, core")
                        exercise("gym", "Cable lateral raise", "Cable · Side delts")
                    }
                    .padding(.top, 8)

                    SectionHeader(title: "All shoulders", note: "Gear you own").padding(.top, 22)
                    HairlineStack {
                        exercise("bar-pull", "Overhead press", "Barbell · Swapped out Tuesday")
                        exercise("curl", "Arnold press", "Dumbbell · Front and side delts")
                        exercise("pushup", "Pike push-up", "Bodyweight · Front delts, triceps")
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .azScreen()
    }

    private func exercise(_ photo: String, _ name: String, _ detail: String, changedByDiv: Bool = false, tag: String? = nil) -> some View {
        Button {
            router.push(.exercise)
        } label: {
            HStack(spacing: 14) {
                PhotoTile(name: photo)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(name).font(.az(16, .bold)).lineLimit(1)
                        if changedByDiv { DivMark(size: 16) }
                    }
                    Text(detail).font(.az(14)).foregroundStyle(AZColor.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let tag {
                    Text(tag).font(.az(13, .bold)).foregroundStyle(AZColor.divInk)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(AZColor.divTint, in: .rect(cornerRadius: 8, style: .continuous))
                        .fixedSize()
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(AZColor.faint)
                }
            }
            .frame(minHeight: 64)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { SwapExerciseView() }.environment(Router())
}
