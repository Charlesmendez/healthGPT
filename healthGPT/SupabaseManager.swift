import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    private let client: SupabaseClient

    private init() {
        // Supabase URL
        let supabaseURLString = "https://gxkwcyzaisvjhivigjhk.supabase.co"

        // Load Supabase anon key from plist
        guard let plistPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plistDict = NSDictionary(contentsOfFile: plistPath),
              let supabaseAnonKey = plistDict["anon"] as? String,
              let supabaseURL = URL(string: supabaseURLString)
        else {
            fatalError("Supabase anon key not found in plist or invalid URL")
        }

        client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseAnonKey)
    }

    private func getUserID() async throws -> UUID {
        // Retrieve the current session
        let session = try await client.auth.session

        // Return the user ID as a UUID
        return session.user.id
    }


    func saveReadinessScore(date: Date, score: Int, load: Double?) async throws {
        let userID = try await getUserID()

        let data = ReadinessScoreEntry(id: nil, userID: userID, date: date, score: score, load: load)

        _ = try await client
            .from("readiness_scores")
            .insert([data])
            .execute()
    }

    func fetchReadinessScores() async throws -> [ReadinessScoreEntry] {
        let userID = try await getUserID()

        let data: [ReadinessScoreEntry] = try await client
            .from("readiness_scores")
            .select("*") // This will include the 'load' field
            .eq("user_id", value: userID)
            .order("date", ascending: false)
            .execute()
            .value

            // Debug print raw data fetched
            print("Fetched readiness scores:")
            for entry in data {
                print("Date: \(entry.date), Score: \(entry.score), User ID: \(entry.userID)")
            }

            // Group data by day and select the latest entry per day
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0) // Ensure UTC

            let grouped = Dictionary(grouping: data) { entry -> String in
                return formatter.string(from: entry.date)
            }

            // Debug print the groups
            print("Grouped data by day:")
            for (dateString, entries) in grouped {
                print("Date: \(dateString), Entries: \(entries.count)")
                for entry in entries {
                    print("  Entry date: \(entry.date), score: \(entry.score)")
                }
            }

            // Select the latest entry per day
            let latestEntriesPerDay = grouped.compactMap { (_, entries) -> ReadinessScoreEntry? in
                entries.sorted(by: { $0.date > $1.date }).first
            }.sorted(by: { $0.date < $1.date }) // Sort by date ascending

            // Print final selected entries
            print("Latest entries per day:")
            for entry in latestEntriesPerDay {
                print("Date: \(entry.date), Score: \(entry.score)")
            }

            return latestEntriesPerDay
        }
}

struct ReadinessScoreEntry: Codable, Identifiable {
    let id: UUID?
    let userID: UUID
    let date: Date
    let score: Int
    let load: Double? // New property

    init(id: UUID? = nil, userID: UUID, date: Date, score: Int, load: Double?) {
        self.id = id
        self.userID = userID
        self.date = date
        self.score = score
        self.load = load
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case date
        case score
        case load
    }

    // Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        userID = try container.decode(UUID.self, forKey: .userID)
        score = try container.decode(Int.self, forKey: .score)
        load = try container.decodeIfPresent(Double.self, forKey: .load) // Decode load
        let dateString = try container.decode(String.self, forKey: .date)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        if let date = formatter.date(from: dateString) {
            self.date = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .date,
                                                   in: container,
                                                   debugDescription: "Invalid date format: \(dateString)")
        }
    }

    // Custom Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(score, forKey: .score)
        try container.encodeIfPresent(load, forKey: .load) // Encode load

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: date)
        try container.encode(dateString, forKey: .date)
    }
}
