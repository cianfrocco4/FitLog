import SwiftUI

struct WeekSummaryView: View {
    let completedWorkouts: Int
    
    var body: some View {
        VStack(spacing: 12) {
            Text("This Week")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("\(completedWorkouts)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
            
            Text(completedWorkouts == 1 ? "workout completed" : "workouts completed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}