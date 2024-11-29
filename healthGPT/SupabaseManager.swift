import Foundation
import Supabase


class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient
    
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
        
        // Get the local time zone
        let localTimeZone = TimeZone.current
        
        // Adjust the date to local time zone
        let calendar = Calendar.current
        let localDate = calendar.date(byAdding: .second, value: localTimeZone.secondsFromGMT(for: date), to: date)!
        
        let data = ReadinessScoreEntry(id: nil, userID: userID, date: localDate, score: score, load: load)
        
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
    
    func sendFriendInvite(email: String) async throws {
        // Get current user session
        let session = try await client.auth.session
        let currentUserId = session.user.id
        
        // Normalize the email
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Log the email
        print("Attempting to send invite to email: \(normalizedEmail)")
        
        // Fetch profiles matching the email
        let profiles: [Profile] = try await client
            .from("profiles")
            .select("id, email")
            .eq("email", value: normalizedEmail)
            .execute()
            .value
        
        // Log the profiles
        print("Profiles: \(profiles)")
        
        if profiles.count == 1,
           let receiverId = profiles.first?.id {
            // Create friend_invite record
            let inviteData = FriendInviteInput(sender_id: currentUserId, receiver_id: receiverId, status: "pending")
            
            _ = try await client
                .from("friend_invites")
                .insert(inviteData)
                .execute()
            print("Friend invite sent successfully.")
        } else if profiles.isEmpty {
            throw NSError(domain: "SupabaseManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "User with email not found"])
        } else {
            throw NSError(domain: "SupabaseManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Multiple users with the same email found"])
        }
    }
    
    func fetchPendingInvites() async throws -> [FriendInvite] {
        print("Fetching session...")
        let session = try await client.auth.session
        print("Session retrieved: \(session)")
        
        let currentUserId = session.user.id
        print("Current user ID: \(currentUserId)")
        
        print("Querying database...")
        
        // Define the response type with created_at as String
        struct FriendInviteResponse: Codable {
            let id: UUID
            let sender_id: UUID
            let status: String
            let created_at: String  // Keep as String
            let sender: SenderProfile?
            
            struct SenderProfile: Codable {
                let email: String
            }
        }
        
        // Execute the query and specify the expected return type
        let response: PostgrestResponse<[FriendInviteResponse]> = try await client
            .from("friend_invites")
            .select("id, sender_id, status, created_at, sender:sender_id(email)")
            .eq("receiver_id", value: currentUserId.uuidString)
            .eq("status", value: "pending")
            .execute()
        
        let data = response.value
        
        print("Data received: \(data.count) entries found")
        for item in data {
            print("Entry: \(item)")
        }
        
        // Create an ISO8601DateFormatter with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Process the data, parsing the date manually
        let invites = data.compactMap { item -> FriendInvite? in
            // Parse the created_at date
            guard let createdAt = isoFormatter.date(from: item.created_at) else {
                print("Failed to parse date: \(item.created_at)")
                return nil
            }
            
            let senderEmail = item.sender?.email ?? "Unknown"
            
            return FriendInvite(
                id: item.id,
                senderId: item.sender_id,
                senderEmail: senderEmail,
                receiverId: currentUserId,
                status: item.status,
                createdAt: createdAt
            )
        }
        
        print("Processed invites: \(invites.count) valid entries")
        return invites
    }
    
    func acceptInvite(inviteId: UUID) async throws {
        print("Accepting invite with ID: \(inviteId)")
        
        // Update invite status to 'accepted'
        let updateResponse = try await client
            .from("friend_invites")
            .update(["status": "accepted"])
            .eq("id", value: inviteId.uuidString)
            .execute()
        
        // Check the response status or catch errors
        if updateResponse.status != 200 {
            print("Error updating invite status: HTTP Status \(updateResponse.status)")
            throw NSError(domain: "SupabaseManager", code: updateResponse.status, userInfo: [NSLocalizedDescriptionKey: "Failed to update invite status."])
        } else {
            print("Invite status updated successfully")
        }
        
        // Define the response type with expected keys
        struct FriendInviteResponse: Codable {
            let sender_id: String
            let receiver_id: String
        }
        
        // Fetch the invite to get sender_id and receiver_id
        let response: PostgrestResponse<[FriendInviteResponse]> = try await client
            .from("friend_invites")
            .select("sender_id, receiver_id")
            .eq("id", value: inviteId.uuidString)
            .execute()
        
        let data = response.value
        print("Data received: \(data.count) entries found")
        for item in data {
            print("Entry: \(item)")
        }
        
        // Ensure the data has one entry
        guard let item = data.first else {
            print("No valid data found in invite response.")
            throw NSError(domain: "SupabaseManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid invite data"])
        }
        
        guard let senderId = UUID(uuidString: item.sender_id),
              let receiverId = UUID(uuidString: item.receiver_id) else {
            print("Invalid UUIDs: sender_id = \(item.sender_id), receiver_id = \(item.receiver_id)")
            throw NSError(domain: "SupabaseManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid sender or receiver UUIDs"])
        }
        
        print("Sender ID: \(senderId), Receiver ID: \(receiverId)")
        
        // Create friendships in both directions using the struct
        let friendshipsData: [FriendshipData] = [
            FriendshipData(user_id: senderId.uuidString, friend_id: receiverId.uuidString),
            FriendshipData(user_id: receiverId.uuidString, friend_id: senderId.uuidString)
        ]
        
        let insertResponse = try await client
            .from("friendships")
            .insert(friendshipsData)
            .execute()
        
        if insertResponse.status != 201 {
            print("Error inserting friendship: HTTP Status \(insertResponse.status)")
            throw NSError(domain: "SupabaseManager", code: insertResponse.status, userInfo: [NSLocalizedDescriptionKey: "Failed to create friendships."])
        } else {
            print("Friendship insert successful: \(insertResponse)")
        }
    }
    
    func declineInvite(inviteId: UUID) async throws {
        print("Declining invite with ID: \(inviteId)")
        
        let updateResponse = try await client
            .from("friend_invites")
            .update(["status": "declined"])
            .eq("id", value: inviteId.uuidString)
            .execute()
        
        if updateResponse.status != 200 {
            print("Error updating invite status: HTTP Status \(updateResponse.status)")
            throw NSError(domain: "SupabaseManager", code: updateResponse.status, userInfo: [NSLocalizedDescriptionKey: "Failed to update invite status."])
        } else {
            print("Invite status updated successfully")
        }
    }
    
    func fetchFriends() async throws -> [Friend] {
        print("Fetching session for friends...")
        let session = try await client.auth.session
        print("Session retrieved: \(session)")

        let currentUserId = session.user.id
        print("Current user ID: \(currentUserId)")

        print("Querying friendships database...")

        // Define the response type
        struct FriendResponse: Codable {
            let friend_id: UUID
            let friend: FriendProfile

            struct FriendProfile: Codable {
                let email: String
            }
        }

        // Execute the query
        let response: PostgrestResponse<[FriendResponse]> = try await client
            .from("friendships")
            .select("friend_id, friend:friend_id(email)")
            .eq("user_id", value: currentUserId.uuidString)
            .execute()

        let data = response.value

        print("Data received: \(data.count) entries found")
        for item in data {
            print("Entry: \(item)")
        }

        // Map data to Friend objects
        let friends = data.map { item in
            Friend(id: item.friend_id, email: item.friend.email)
        }

        print("Processed friends: \(friends.count) entries")
        return friends
    }

    func fetchFriendsReadinessScores() async throws -> [FriendReadinessScore] {
        print("Fetching friends for readiness scores...")
        let friends = try await fetchFriends()
        print("Friends fetched: \(friends.count)")

        let friendIds = friends.map { $0.id.uuidString }
        print("Friend IDs for readiness scores query: \(friendIds)")

        guard !friendIds.isEmpty else {
            print("No friends found. Returning empty readiness scores.")
            return []
        }

        print("Querying readiness_scores database...")

        struct ReadinessScoreResponse: Codable {
            let id: UUID
            let date: String
            let score: Int
            let load: Double?
            let user_id: UUID
        }

        // Execute the query
        let response: PostgrestResponse<[ReadinessScoreResponse]> = try await client
            .from("readiness_scores")
            .select("id, date, score, load, user_id")
            .in("user_id", values: friendIds)
            .order("user_id")
            .order("date", ascending: false)
            .execute()

        let data = response.value

        print("Data received: \(data.count) entries found")
        for item in data {
            print("Entry: \(item)")
        }

        // Use DateFormatter instead of ISO8601DateFormatter
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)  // Adjust if necessary
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        var latestScoresDict = [UUID: FriendReadinessScore]()

        for item in data {
            // Parse the date
            guard let date = dateFormatter.date(from: item.date) else {
                print("Failed to parse date: \(item.date)")
                continue
            }

            // Find the friend for this user_id
            guard let friend = friends.first(where: { $0.id == item.user_id }) else {
                print("No matching friend found for user_id: \(item.user_id)")
                continue
            }

            // Handle optional load value
            guard let loadScore = item.load else {
                print("Load value is nil for readiness score ID: \(item.id)")
                continue
            }

            // If we haven't added a score for this user yet, add it
            if latestScoresDict[item.user_id] == nil {
                let readinessScore = FriendReadinessScore(
                    id: item.id,
                    friend: friend,
                    readinessScore: item.score,
                    loadScore: loadScore,
                    date: date
                )
                latestScoresDict[item.user_id] = readinessScore
            }
        }

        let readinessScores = Array(latestScoresDict.values)

        print("Processed readiness scores: \(readinessScores.count) entries")
        return readinessScores
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

struct FriendReadinessScore: Identifiable, Codable {
    var id: UUID
    var friend: Friend
    var readinessScore: Int
    var loadScore: Double
    var date: Date
}

struct Profile: Codable {
    let id: UUID
    let email: String
}
