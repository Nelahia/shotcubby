import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 36))
                .foregroundStyle(Color("TextSecondary"))
            Text("No screenshots yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("TextPrimary"))
            Text("Take a screenshot (⌘⇧3 or ⌘⇧4)\nand it will appear here")
                .font(.system(size: 12))
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
