import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Errors that can occur when interacting with the Clockify API
enum ClockifyError: LocalizedError {
    case missingAPIKey
    case missingWorkspaceId
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noDataReceived
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "CLOCKIFY_API_KEY environment variable is not set"
        case .missingWorkspaceId:
            return "CLOCKIFY_WORKSPACE_ID environment variable is not set"
        case .invalidURL:
            return "Invalid URL constructed for API request"
        case .invalidResponse:
            return "Invalid response received from API"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .noDataReceived:
            return "No data received from API"
        }
    }
}

/// Client for interacting with the Clockify API
///
/// This client handles all communication with the Clockify REST API.
/// It requires the following environment variables to be set:
/// - `CLOCKIFY_API_KEY`: Your Clockify API key (obtainable from https://clockify.me/user/settings)
/// - `CLOCKIFY_WORKSPACE_ID`: Your Clockify workspace ID
///
/// Example:
/// ```swift
/// let client = try ClockifyClient()
/// let timer = try await client.startTimer(description: "Working on feature")
/// ```
class ClockifyClient {
    private let apiKey: String
    private let workspaceId: String
    private let baseURL = "https://api.clockify.me/api/v1"
    private let session: URLSession
    
    /// Initialize a new Clockify client
    ///
    /// - Throws: `ClockifyError.missingAPIKey` if CLOCKIFY_API_KEY is not set
    /// - Throws: `ClockifyError.missingWorkspaceId` if CLOCKIFY_WORKSPACE_ID is not set
    init() throws {
        guard let apiKey = ProcessInfo.processInfo.environment["CLOCKIFY_API_KEY"] else {
            throw ClockifyError.missingAPIKey
        }
        guard let workspaceId = ProcessInfo.processInfo.environment["CLOCKIFY_WORKSPACE_ID"] else {
            throw ClockifyError.missingWorkspaceId
        }
        
        self.apiKey = apiKey
        self.workspaceId = workspaceId
        self.session = URLSession.shared
    }
    
    /// Get the current user information
    ///
    /// - Returns: User information including user ID
    /// - Throws: API errors if the request fails
    func getCurrentUser() async throws -> User {
        guard let url = URL(string: "\(baseURL)/user") else {
            throw ClockifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClockifyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClockifyError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(User.self, from: data)
    }
    
    /// Start a new timer
    ///
    /// - Parameters:
    ///   - description: Optional description for the time entry
    ///   - projectId: Optional project ID to associate with this timer
    /// - Returns: The created time entry with the running timer
    /// - Throws: API errors if the request fails
    func startTimer(description: String? = nil, projectId: String? = nil) async throws -> TimeEntry {
        guard let url = URL(string: "\(baseURL)/workspaces/\(workspaceId)/time-entries") else {
            throw ClockifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body
        var body: [String: Any] = [
            "start": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let description = description {
            body["description"] = description
        }
        
        if let projectId = projectId {
            body["projectId"] = projectId
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClockifyError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClockifyError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TimeEntry.self, from: data)
    }
    
    /// Get the currently running timer, if any
    ///
    /// - Returns: The current time entry if a timer is running, nil otherwise
    /// - Throws: API errors if the request fails
    func getCurrentTimer() async throws -> TimeEntry? {
        let user = try await getCurrentUser()
        
        guard let url = URL(string: "\(baseURL)/workspaces/\(workspaceId)/user/\(user.id)/time-entries?in-progress=true") else {
            throw ClockifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClockifyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClockifyError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([TimeEntry].self, from: data)
        
        return entries.first
    }
    
    /// Stop the currently running timer
    ///
    /// - Parameters:
    ///   - userId: The user ID
    ///   - workspaceId: The workspace ID
    /// - Returns: The stopped time entry
    /// - Throws: API errors if the request fails
    func stopTimer(userId: String, workspaceId: String) async throws -> TimeEntry {
        guard let url = URL(string: "\(baseURL)/workspaces/\(workspaceId)/user/\(userId)/time-entries") else {
            throw ClockifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "end": ISO8601DateFormatter().string(from: Date())
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClockifyError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClockifyError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TimeEntry.self, from: data)
    }
    
    /// Get time entries for a user within a date range
    ///
    /// - Parameters:
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    /// - Returns: Array of time entries within the date range
    /// - Throws: API errors if the request fails
    func getTimeEntries(startDate: Date, endDate: Date) async throws -> [TimeEntry] {
        let user = try await getCurrentUser()
        
        let formatter = ISO8601DateFormatter()
        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: endDate)
        
        guard let url = URL(string: "\(baseURL)/workspaces/\(workspaceId)/user/\(user.id)/time-entries?start=\(startString)&end=\(endString)") else {
            throw ClockifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClockifyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClockifyError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([TimeEntry].self, from: data)
    }
}

// MARK: - Data Models

/// Represents a Clockify user
struct User: Codable {
    let id: String
    let email: String
    let name: String
}

/// Represents a time interval with start and optional end
struct TimeInterval: Codable {
    let start: Date
    let end: Date?
    
    enum CodingKeys: String, CodingKey {
        case start
        case end
    }
}

/// Represents a Clockify time entry
struct TimeEntry: Codable {
    let id: String
    let description: String?
    let userId: String
    let workspaceId: String
    let projectId: String?
    let timeInterval: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case id
        case description
        case userId
        case workspaceId
        case projectId
        case timeInterval
    }
}
