import SwiftUI

enum FocusSessionStatus {
    case idle
    case active
    case paused
    case completed
}

struct FocusView: View {
    @State private var sessionStatus: FocusSessionStatus = .idle
    @State private var sessionSeconds = 0
    @State private var completedSeconds = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            switch sessionStatus {
            case .idle:
                startSessionView
            case .active, .paused:
                activeSessionView
            case .completed:
                completionView
            }
        }
        .navigationTitle("Focus")
    }
    
    private var startSessionView: some View {
        ScrollView {
            VStack(spacing: 32) {
                startSessionButton
                joinSection
                Spacer()
                    .frame(height: 40)
            }
        }
    }
    
    private var startSessionButton: some View {
        Button(action: {
            startSession()
        }) {
            Text("Start\nSession")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(width: 220, height: 220)
                .background(
                    Circle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: 3)
                        )
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 40)
    }
    
    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Join:")
                .font(.title2)
                .bold()
            
            friendSessionRow(name: "Alice", duration: "30m")
            friendSessionRow(name: "James", duration: "1hr")
        }
        .padding(.horizontal, 24)
    }
    
    private func friendSessionRow(name: String, duration: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 44, height: 44)
            
            Text(name)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                )
            
            Text(duration)
                .font(.title3)
                .bold()
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(Color(.systemGreen).opacity(0.3))
                )
        }
    }
    
    private var activeSessionView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Text(formattedTime)
                .font(.system(size: 80, weight: .bold))
            
            if sessionStatus == .paused {
                Text("Get back to it!")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            
            Spacer()
            
            sessionControls
        }
    }
    
    private var sessionControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button(sessionStatus == .paused ? "Resume" : "Pause") {
                    togglePause()
                }
                .buttonStyle(.bordered)
                .frame(width: 140, height: 50)
                
                Button("Stop") {
                    stopSession()
                }
                .buttonStyle(.bordered)
                .frame(width: 140, height: 50)
            }
            
            Button("mood session") {
                // Action to be implemented
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 300, height: 50)
        }
        .padding(.bottom, 80)
    }
    
    private var completionView: some View {
        ScrollView {
            VStack(spacing: 32) {
                completionHeader
                readingTimeSummary
                
                Button("mood session stats") {
                    // Action to be implemented
                }
                .buttonStyle(.borderedProminent)
                .frame(width: 300, height: 50)
                
                challengeProgressSection
                
                Spacer()
                    .frame(height: 40)
            }
        }
    }
    
    private var completionHeader: some View {
        HStack {
            Button("close") {
                closeCompletion()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var readingTimeSummary: some View {
        VStack(spacing: 8) {
            Text("You read")
                .font(.title2)
            Text("for")
                .font(.title3)
            Text(formattedCompletedTime)
                .font(.system(size: 60, weight: .bold))
            Text("time")
                .font(.title)
        }
        .frame(width: 280, height: 280)
        .background(
            Circle()
                .fill(Color(.systemGreen).opacity(0.3))
        )
    }
    
    private var challengeProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Challenge Progress:")
                .font(.headline)
            
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Slider(value: .constant(0.3), in: 0...1)
                        .disabled(true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                )
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var formattedTime: String {
        let minutes = sessionSeconds / 60
        let seconds = sessionSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var formattedCompletedTime: String {
        let minutes = completedSeconds / 60
        let seconds = completedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func startSession() {
        sessionStatus = .active
        sessionSeconds = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            sessionSeconds += 1
        }
    }
    
    private func togglePause() {
        if sessionStatus == .paused {
            // Resume the timer
            sessionStatus = .active
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                sessionSeconds += 1
            }
        } else {
            // Pause the timer
            sessionStatus = .paused
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func stopSession() {
        timer?.invalidate()
        timer = nil
        
        // Save the completed time and show completion view
        completedSeconds = sessionSeconds
        sessionStatus = .completed
    }
    
    private func closeCompletion() {
        sessionStatus = .idle
        sessionSeconds = 0
        completedSeconds = 0
    }
}

struct FocusView_Previews: PreviewProvider {
    static var previews: some View {
        FocusView()
    }
}
