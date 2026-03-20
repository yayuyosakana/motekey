import SwiftUI

struct CheckmarkAnimationView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 100, height: 100)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .scaleEffect(appeared ? 1.0 : 0.7)
                .opacity(appeared ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }
}
