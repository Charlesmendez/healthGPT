//
//  CommandModel.swift
//  Rove
//
//  Created by Carlos Fernando Mendez Solano on 4/23/23.
//

import Foundation

struct Command: Encodable {
    let prompt: String
    let model: String
    let maxTokens: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case prompt
        case model
        case maxTokens = "max_tokens"
        case temperature
    }
}
