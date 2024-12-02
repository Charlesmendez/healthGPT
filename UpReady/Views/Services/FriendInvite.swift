//
//  FriendInvite.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 11/28/24.
//

// FriendInvite.swift
import Foundation

struct FriendInvite: Identifiable, Codable {
    var id: UUID
    var senderId: UUID
    var senderEmail: String
    var receiverId: UUID
    var status: String
    var createdAt: Date
}

// Friend.swift
import Foundation

struct Friend: Identifiable, Codable {
    var id: UUID
    var email: String
}

struct FriendInviteInput: Codable {
    var sender_id: UUID
    var receiver_id: UUID
    var status: String
}

struct FriendshipData: Codable {
    var user_id: String
    var friend_id: String
}
