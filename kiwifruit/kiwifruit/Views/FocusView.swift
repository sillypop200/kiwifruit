import SwiftUI

struct FocusView: View {
    @State private var isSessionActive = false
    @State private var isPaused = false
    @State private var showingCompletion = false
    @State private var sessionSeconds = 0
    @State private var completedSeconds = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            if showingCompletion {
                completionView
            } else if isSessionActive {
                activeSessionView
            } else {
                startSessionView
            }
        }
        .navigationTitle("Focus")
    }
    
    // View shown before starting a session
    private var startSessionView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Start Session Button (large circle)
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
                
                // Join section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Join:")
                        .font(.title2)
                        .bold()
                    
                    // Friend session row 1
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44)
                        
                        Text("Alice")
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemGray6))
                            )
                        
                        Text("30m")
                            .font(.title3)
                            .bold()
                            .frame(width: 80, height: 80)
                            .background(
                                Circle()
                                    .fill(Color(.systemGreen).opacity(0.3))
                            )
                    }
                    
                    // Friend session row 2
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44)
                        
                        Text("James")
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemGray6))
                            )
                        
                        Text("1hr")
                            .font(.title3)
                            .bold()
                            .frame(width: 80, height: 80)
                            .background(
                                Circle()
                                    .fill(Color(.systemGreen).opacity(0.3))
                            )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                    .frame(height: 40)
            }
        }
    }
    
    // View shown during active session
    private var activeSessionView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Timer display
            Text(formattedTime)
                .font(.system(size: 80, weight: .bold))
            
            // Show motivational quote when paused
            if isPaused {
                Text("Get back to it!")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            
            Spacer()
            
            // Control buttons
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    Button(isPaused ? "Resume" : "Pause") {
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
    }
    
    // View shown after completing a session
    private var completionView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Close button at top
                HStack {
                    Button("close") {
                        closeCompletion()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                Spacer()
                    .frame(height: 20)
                
                // Reading time summary circle
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
                
                // Mood session stats button
                Button("mood session stats") {
                    // Action to be implemented
                }
                .buttonStyle(.borderedProminent)
                .frame(width: 300, height: 50)
                
                // Challenge Progress section
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
                
                Spacer()
                    .frame(height: 40)
            }
        }
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
        isSessionActive = true
        isPaused = false
        showingCompletion = false
        sessionSeconds = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            sessionSeconds += 1
        }
    }
    
    private func togglePause() {
        isPaused.toggle()
        
        if isPaused {
            // Pause the timer
            timer?.invalidate()
            timer = nil
        } else {
            // Resume the timer
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                sessionSeconds += 1
            }
        }
    }
    
    private func stopSession() {
        isSessionActive = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        
        // Save the completed time and show completion view
        completedSeconds = sessionSeconds
        showingCompletion = true
    }
    
    private func closeCompletion() {
        showingCompletion = false
        sessionSeconds = 0
        completedSeconds = 0
    }
}

struct FocusView_Previews: PreviewProvider {
    static var previews: some View {
        FocusView()
    }
}
