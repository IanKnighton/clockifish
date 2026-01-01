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
        subcommands: [Timer.self, Report.self],
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
            abstract: "Check the status of the current timer",
            subcommands: [Id.self]
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
        
        /// Get just the ID of the current timer
        struct Id: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Get just the ID of the current timer"
            )
            
            func run() async throws {
                let client = try ClockifyClient()
                
                if let currentTimer = try await client.getCurrentTimer() {
                    print(currentTimer.id)
                } else {
                    print("no timer")
                    throw ExitCode.failure
                }
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

/// Report subcommand for generating time reports
struct Report: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "report",
        abstract: "Generate time reports for the week and month",
        subcommands: [Week.self, Month.self]
    )
    
    func run() async throws {
        // Default behavior: show both week and month reports
        let weekReport = Week()
        let monthReport = Month()
        
        print("📊 Time Report\n")
        
        print("Week (Monday - Sunday):")
        try await weekReport.run()
        
        print("\nMonth:")
        try await monthReport.run()
    }
}

extension Report {
    /// Calculate total hours from time entries
    static func calculateTotalHours(from entries: [TimeEntry]) -> Double {
        var totalSeconds: Double = 0
        
        for entry in entries {
            guard let endDate = entry.timeInterval.end else {
                continue
            }
            let duration = endDate.timeIntervalSince(entry.timeInterval.start)
            totalSeconds += duration
        }
        
        return totalSeconds / 3600.0
    }
    
    /// Get the start of the current week (Monday)
    static func getStartOfWeek() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the weekday (1 = Sunday, 2 = Monday, etc.)
        let weekday = calendar.component(.weekday, from: now)
        
        // Calculate days to subtract to get to Monday (weekday 2)
        // If Sunday (1), go back 6 days. If Monday (2), go back 0 days, etc.
        let daysToSubtract = weekday == 1 ? 6 : weekday - 2
        
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: now) else {
            return calendar.startOfDay(for: now)
        }
        return calendar.startOfDay(for: startOfWeek)
    }
    
    /// Get the end of the current week (Sunday at end of day)
    static func getEndOfWeek() -> Date {
        let calendar = Calendar.current
        let startOfWeek = getStartOfWeek()
        
        // Add 7 days to get to the start of next Monday
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
            return startOfWeek
        }
        return endOfWeek
    }
    
    /// Get the start of the current month
    static func getStartOfMonth() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: components) ?? calendar.startOfDay(for: now)
    }
    
    /// Get the end of the current month
    static func getEndOfMonth() -> Date {
        let calendar = Calendar.current
        let startOfMonth = getStartOfMonth()
        
        // Add 1 month to get start of next month
        guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return startOfMonth
        }
        return endOfMonth
    }
    
    /// Format a date range end for display (subtracts 1 second from the end date)
    static func formatEndDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        guard let adjustedDate = calendar.date(byAdding: .second, value: -1, to: date) else {
            return formatter.string(from: date)
        }
        return formatter.string(from: adjustedDate)
    }
    
    /// Week report subcommand
    struct Week: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show time report for the current week (Monday - Sunday)"
        )
        
        @Flag(name: .long, help: "Output just the numeric value (hours to 2 decimal places)")
        var raw = false
        
        func run() async throws {
            let client = try ClockifyClient()
            
            let startDate = Report.getStartOfWeek()
            let endDate = Report.getEndOfWeek()
            
            let entries = try await client.getTimeEntries(startDate: startDate, endDate: endDate)
            let totalHours = Report.calculateTotalHours(from: entries)
            
            if raw {
                print(String(format: "%.2f", totalHours))
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                
                print("Week: \(formatter.string(from: startDate)) - \(Report.formatEndDate(endDate))")
                print("Total Hours: \(String(format: "%.2f", totalHours))")
            }
        }
    }
    
    /// Month report subcommand
    struct Month: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show time report for the current month"
        )
        
        @Flag(name: .long, help: "Output just the numeric value (hours to 2 decimal places)")
        var raw = false
        
        func run() async throws {
            let client = try ClockifyClient()
            
            let startDate = Report.getStartOfMonth()
            let endDate = Report.getEndOfMonth()
            
            let entries = try await client.getTimeEntries(startDate: startDate, endDate: endDate)
            let totalHours = Report.calculateTotalHours(from: entries)
            
            if raw {
                print(String(format: "%.2f", totalHours))
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                
                print("Month: \(formatter.string(from: startDate)) - \(Report.formatEndDate(endDate))")
                print("Total Hours: \(String(format: "%.2f", totalHours))")
            }
        }
    }
}

