import ArgumentParser
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The main entry point for the clockifish CLI application.
///
/// Clockifish is a command-line tool for interacting with the Clockify time tracking API.
/// It allows users to start, stop, and check the status of timers directly from the terminal.
///
/// Required environment variables:
/// - `CLOCKIFY_API_KEY`: Your Clockify API key
/// - `CLOCKIFY_WORKSPACE_ID`: Your Clockify workspace ID
///
/// Example usage:
/// ```
/// clockifish timer start
/// clockifish timer stop
/// clockifish timer status
/// ```
@main
struct Clockifish: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clockifish",
        abstract: "A CLI for interacting with the Clockify API",
        version: getVersion(),
        subcommands: [Timer.self],
        defaultSubcommand: Timer.self
    )
    
    /// Get the version string, either from environment variable (for builds) or git tag (for development)
    static func getVersion() -> String {
        // Check for embedded version (set during Homebrew build)
        if let embeddedVersion = ProcessInfo.processInfo.environment["CLOCKIFISH_VERSION"] {
            return embeddedVersion
        }
        
        // Fallback to hardcoded version for development
        return "1.0.0"
    }
}

/// Timer subcommand for managing time entries
struct Timer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "timer",
        abstract: "Manage timers in Clockify",
        subcommands: [Start.self, Stop.self, Status.self]
    )
}

extension Timer {
    /// Start a new timer
    struct Start: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Start a new timer"
        )
        
        @Option(name: .shortAndLong, help: "Description for the time entry")
        var description: String?
        
        @Option(name: .shortAndLong, help: "Project ID to associate with this timer")
        var project: String?
        
        func run() async throws {
            let client = try ClockifyClient()
            let timeEntry = try await client.startTimer(description: description, projectId: project)
            
            print("✓ Timer started successfully")
            print("ID: \(timeEntry.id)")
            if let desc = timeEntry.description, !desc.isEmpty {
                print("Description: \(desc)")
            }
            print("Started at: \(Timer.formatDate(timeEntry.timeInterval.start))")
        }
    }
    
    /// Stop the currently running timer
    struct Stop: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Stop the currently running timer"
        )
        
        func run() async throws {
            let client = try ClockifyClient()
            
            // First, get the current timer
            guard let currentTimer = try await client.getCurrentTimer() else {
                print("No timer is currently running")
                return
            }
            
            // Stop the timer
            let stoppedEntry = try await client.stopTimer(userId: currentTimer.userId, workspaceId: currentTimer.workspaceId)
            
            print("✓ Timer stopped successfully")
            print("ID: \(stoppedEntry.id)")
            if let desc = stoppedEntry.description, !desc.isEmpty {
                print("Description: \(desc)")
            }
            print("Duration: \(Timer.formatDuration(from: stoppedEntry.timeInterval.start, to: stoppedEntry.timeInterval.end))")
        }
    }
    
    /// Check the status of the current timer
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Check the status of the current timer"
        )
        
        func run() async throws {
            let client = try ClockifyClient()
            
            if let currentTimer = try await client.getCurrentTimer() {
                print("⏱  Timer is running")
                print("ID: \(currentTimer.id)")
                if let desc = currentTimer.description, !desc.isEmpty {
                    print("Description: \(desc)")
                }
                print("Started at: \(Timer.formatDate(currentTimer.timeInterval.start))")
                print("Duration: \(Timer.formatDuration(from: currentTimer.timeInterval.start, to: Date()))")
            } else {
                print("No timer is currently running")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Format a date for display
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Format duration between two dates
    static func formatDuration(from start: Date, to end: Date?) -> String {
        let endDate = end ?? Date()
        let duration = endDate.timeIntervalSince(start)
        
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}
