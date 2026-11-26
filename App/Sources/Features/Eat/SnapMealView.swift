import AZModel
import AZSync
import PhotosUI
import SwiftUI

/// The meal camera: take a photo or pick one from the library, and Div estimates it on the Mac. Every photo is shrunk
/// to a JPEG Claude reads whole (`PhotoPrep`) before it leaves the phone. Design: design/source/src/Snap.html
struct SnapMealView: View {
    @Environment(Router.self) private var router
    @State private var camera = MealCamera()
    @State private var problem: MealCamera.Problem?
    @State private var isStarting = true
    @State private var flash = false
    @State private var isCapturing = false
    @State private var isPicking = false
    @State private var picked: PhotosPickerItem?
    @State private var unreadable = false

    var body: some View {
        ZStack {
            AZColor.Camera.shade.ignoresSafeArea()
            if problem == nil {
                CameraPreview(session: camera.session).ignoresSafeArea()
            }
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [AZColor.Camera.shade.opacity(0.55), AZColor.Camera.shade.opacity(0)], startPoint: .top, endPoint: .bottom
                )
                .frame(height: 170)
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: AZColor.Camera.shade.opacity(0), location: 0),
                        .init(color: AZColor.Camera.shade.opacity(0.9), location: 0.5),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 330)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .overlay { content }
        .environment(\.colorScheme, .dark)
        .photosPicker(isPresented: $isPicking, selection: $picked, matching: .images, preferredItemEncoding: .compatible)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            picked = nil
            Task { await usePicked(item) }
        }
        .task {
            problem = await camera.start()
            isStarting = false
        }
        .onDisappear { camera.stop() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            TopBar {
                glassButton("xmark", "Close camera") { router.dismissCover() }
            } center: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar").font(.system(size: 13, weight: .semibold))
                    Text("Adding to \(Self.dayLabel(.now)) · \(Meal.mealTime(at: .now).lowercased())").font(.az(14, .semibold))
                }
                .foregroundStyle(.white)
                .padding(.leading, 12).padding(.trailing, 14)
                .frame(height: 36)
                .background(AZColor.Camera.scrim, in: .capsule)
                .fixedSize()
            } trailing: {
                glassButton(flash ? "bolt.fill" : "bolt.slash", flash ? "Flash on" : "Flash off") { flash.toggle() }
                    .opacity(problem == nil ? 1 : 0)
            }

            Group {
                if let problem {
                    blocked(problem)
                } else {
                    Brackets().stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
            .frame(height: 364)
            .padding(.horizontal, 28)
            .padding(.top, 34)

            Spacer(minLength: 12)

            if unreadable {
                Text("Couldn't read that photo. Try another one.")
                    .font(.az(14, .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(AZColor.Camera.card, in: .capsule)
            }

            HStack(spacing: 4) {
                mode("Photo", isOn: true) {}
                mode("Add food", isOn: false) { router.dismissCover(thenPush: .addFood(nil)) }
            }
            .padding(.top, 16)

            HStack {
                glassButton("photo", "Choose from photos", size: 52) { isPicking = true }
                Spacer()
                Button {
                    Task { await takePhoto() }
                } label: {
                    RoundedRectangle(cornerRadius: 21, style: .continuous).fill(.white).frame(width: 62, height: 62)
                        .scaleEffect(isCapturing ? 0.86 : 1)
                        .frame(width: 80, height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white, lineWidth: 4))
                        .animation(.snappy(duration: 0.15), value: isCapturing)
                }
                .buttonStyle(.plain)
                .disabled(problem != nil || isStarting || isCapturing)
                .opacity(problem == nil ? 1 : 0.35)
                .accessibilityLabel("Take photo")
                Spacer()
                glassButton("magnifyingglass", "Add food instead", size: 52) { router.dismissCover(thenPush: .addFood(nil)) }
            }
            .padding(.horizontal, 36)
            .padding(.top, 34)
            .padding(.bottom, 12)
        }
    }

    /// No camera: why, and what still works.
    private func blocked(_ problem: MealCamera.Problem) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "camera").font(.system(size: 28, weight: .semibold)).foregroundStyle(AZColor.Camera.muted)
            Text(problem == .denied ? "Camera access is off" : "No camera here").font(.az(17, .bold)).foregroundStyle(.white)
            Text(
                problem == .denied
                    ? "Turn it on in Settings, or choose a photo from your library."
                    : "Choose a photo from your library instead."
            )
            .font(.az(14)).foregroundStyle(AZColor.Camera.muted).multilineTextAlignment(.center)
            if problem == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.az(14, .bold)).foregroundStyle(AZColor.Camera.tagInk)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(.white, in: .capsule)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AZColor.Camera.card, in: .rect(cornerRadius: 28, style: .continuous))
    }

    private func mode(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.az(14, .semibold))
            .foregroundStyle(isOn ? AZColor.Camera.tagInk : .white.opacity(0.62))
            .padding(.horizontal, 14).frame(height: 34)
            .background(isOn ? Color.white : .clear, in: .capsule)
            .buttonStyle(.plain)
    }

    private func takePhoto() async {
        isCapturing = true
        defer { isCapturing = false }
        guard let data = await camera.capture(flash: flash) else { return }
        await use(data, takenAt: .now)
    }

    private func usePicked(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            unreadable = true
            return
        }
        await use(data, takenAt: nil)
    }

    /// Shrinks the photo off the main thread, then opens Div's estimate. A library photo keeps the time it was taken.
    private func use(_ data: Data, takenAt: Date?) async {
        let prepared = await Task.detached(priority: .userInitiated) {
            (jpeg: PhotoPrep.jpeg(from: data), takenAt: PhotoPrep.takenAt(data))
        }.value
        guard let jpeg = prepared.jpeg else {
            unreadable = true
            return
        }
        unreadable = false
        let when = min(takenAt ?? prepared.takenAt ?? .now, .now)
        router.dismissCover(thenPush: .mealEstimate(MealPhoto(jpeg: jpeg, takenAt: when)))
    }

    private func glassButton(_ systemImage: String, _ label: String, size: CGFloat = 44, action: @escaping () -> Void) -> some View {
        IconButton(
            systemImage: systemImage, label: label, size: size,
            background: size > 44 ? AZColor.Camera.glass : AZColor.Camera.scrim, foreground: .white, action: action)
    }

    /// "Today", or "Thu, Nov 19".
    static func dayLabel(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? "today" : date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private nonisolated struct Brackets: Shape {
        func path(in rect: CGRect) -> Path {
            let arm: CGFloat = 34
            let r: CGFloat = 18
            var p = Path()
            for (x, y, sx, sy) in [
                (rect.minX, rect.minY, 1.0, 1.0), (rect.maxX, rect.minY, -1.0, 1.0), (rect.minX, rect.maxY, 1.0, -1.0),
                (rect.maxX, rect.maxY, -1.0, -1.0),
            ] {
                p.move(to: CGPoint(x: x, y: y + sy * arm))
                p.addLine(to: CGPoint(x: x, y: y + sy * r))
                p.addQuadCurve(to: CGPoint(x: x + sx * r, y: y), control: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + sx * arm, y: y))
            }
            return p
        }
    }
}

#Preview {
    SnapMealView().environment(Router())
}
