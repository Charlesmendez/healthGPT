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

    func saveReadinessScore(date: Date, score: Int) async throws {
        let data = ReadinessScoreEntry(id: nil, date: date, score: score)

        _ = try await client
            .from("readiness_scores")
            .insert([data])
            .execute()
    }

    func fetchReadinessScores() async throws -> [ReadinessScoreEntry] {
            let data: [ReadinessScoreEntry] = try await client
                .from("readiness_scores")
                .select()
                .order("date", ascending: false)
                .execute()
                .value

            // Group data by day and select the latest entry per day
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0) // Ensure UTC

            let grouped = Dictionary(grouping: data) { entry -> String in
                return formatter.string(from: entry.date)
            }

            // Debug print the groups
            for (dateString, entries) in grouped {
                print("Date: \(dateString), Entries: \(entries.count)")
                for entry in entries {
                    print("  Entry date: \(entry.date), score: \(entry.score)")
                }
            }

            let latestEntriesPerDay = grouped.compactMap { (_, entries) -> ReadinessScoreEntry? in
                entries.sorted(by: { $0.date > $1.date }).first
            }.sorted(by: { $0.date < $1.date }) // Sort by date ascending

            return latestEntriesPerDay
        }
}

struct ReadinessScoreEntry: Codable, Identifiable {
    let id: UUID?
    let date: Date
    let score: Int

    init(id: UUID? = nil, date: Date, score: Int) {
        self.id = id
        self.date = date
        self.score = score
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case score
    }

    // Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        score = try container.decode(Int.self, forKey: .score)
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
        try container.encode(score, forKey: .score)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: date)
        try container.encode(dateString, forKey: .date)
    }
}
