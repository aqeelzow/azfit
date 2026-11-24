import SwiftUI

/// After the session: totals, the new record, and a recap of what Div changed today.
/// Design: design/source/src/Done.html
struct WorkoutDoneView: View {
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                IconButton(systemImage: "xmark", label: "Close") { router.show(.home) }
            } center: {
                EmptyView()
            } trailing: {
                IconButton(systemImage: "square.and.arrow.up", label: "Share") {}
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DivAvatar(size: 72, mood: .proud).padding(.top, 16)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nice work, Alex").font(.az(34, .heavy)).tracking(-0.85)
                        Text("Push A · 52:18 · Saturday, Nov 21").font(.az(15)).foregroundStyle(AZColor.muted).monospacedDigit()
                    }
                    .padding(.top, 14)

                    HStack(spacing: 0) {
                        stat("Volume", "8,420", unit: "kg")
                        Rectangle().fill(AZColor.hairline).frame(width: 1)
                        stat("Sets", "17", unit: "of 17").padding(.leading, 16)
                        Rectangle().fill(AZColor.hairline).frame(width: 1)
                        stat("Records", "1").padding(.leading, 16)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 28)

                    SectionHeader(title: "New record", note: "History").padding(.top, 30)
                    Button {
                        router.push(.progress)
                    } label: {
                        record
                    }.buttonStyle(.plain).padding(.top, 4)

                    recap.padding(.top, 16)
                }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(title: "Done") { router.show(.home) }
                .padding(.horizontal, AZSpacing.gutter)
                .padding(.bottom, 8)
        }
        .azScreen()
    }

    private func stat(_ label: String, _ value: String, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.az(24, .heavy)).tracking(-0.48)
                if let unit { Text(unit).font(.az(14, .semibold)).foregroundStyle(AZColor.muted) }
            }
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var record: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: "chart.line.uptrend.xyaxis", size: 48, foreground: AZColor.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Bench press").font(.az(16, .bold))
                Text("82.5 kg × 8 · best estimated 1RM").font(.az(14)).foregroundStyle(AZColor.muted).monospacedDigit()
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text("104 kg").font(.az(17, .heavy))
                Text("+2.5").font(.az(13, .bold)).foregroundStyle(AZColor.divInk)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(AZColor.divTint, in: .rect(cornerRadius: 8, style: .continuous))
            }
            .monospacedDigit()
        }
        .frame(minHeight: 64)
        .contentShape(.rect)
    }

    /// "What I changed today": a DivNote whose body is a short list with a purple rule on the left of each line.
    private var recap: some View {
        HStack(alignment: .top, spacing: 12) {
            DivAvatar(size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text("What I changed today").font(.az(15, .bold))
                VStack(alignment: .leading, spacing: 6) {
                    ruled("I lowered set 3 to 6 reps - next week we retry 8.")
                    ruled("Landmine press felt easy at 25 kg. Next time 27.5 kg.")
                }
                .padding(.top, 2)
                PillButton(title: "See Div's log") { router.push(.divLog) }.padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 16))
        .background(AZColor.divTint, in: .rect(cornerRadius: 24, style: .continuous))
    }

    private func ruled(_ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5).fill(AZColor.accentSoft).frame(width: 3).padding(.vertical, 3)
            Text(text).font(.az(14)).foregroundStyle(AZColor.divMuted).fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    NavigationStack { WorkoutDoneView() }.environment(Router())
}
