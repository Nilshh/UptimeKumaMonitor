import SwiftUI

struct StatusBadge: View {
    let isUp: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isUp ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(isUp ? "UP" : "DOWN")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isUp ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusBadge(isUp: true)
        StatusBadge(isUp: false)
    }
    .padding()
}
