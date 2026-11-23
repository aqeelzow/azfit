import SwiftUI

/// Chat with Div, Div's log and "What Div knows".
/// Design: design/screens/Coach.dc.html, Review.dc.html, Memory.dc.html, Voice.dc.html
struct DivChatView: View {
    var body: some View {
        VStack(spacing: AZSpacing.stack) {
            DivAvatar(size: 56)
            Text("Div").font(AZFont.title)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AZColor.background)
    }
}

#Preview { DivChatView() }
