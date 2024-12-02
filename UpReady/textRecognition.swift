//
//  textRecognition.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 12/20/23.
//

import Foundation

final class TextRecognition {
    func findCommonalitiesInArray(keywords: [String]) async -> String? {
        if keywords.count == 1 {
            return keywords.first
        } else {
            let text = keywords.joined(separator: ", ")
            print(text)
            
            var apiKey: String?
            if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
                apiKey = dict["APIKey"] as? String
            }
            
            guard let apiKey = apiKey else {
                print("API Key not found")
                return nil
            }
            
            let openAI = OpenAISwift(authToken: apiKey)
            let chat: [ChatMessage] = [
                ChatMessage(role: .system, content: "You are a helpful doctor."),
                ChatMessage(role: .user, content: """
                Examine each data point and give me a readiness score between 0 and 100. \
                For example 'Your readiness score is 85'. The score can be part of a summary of maximum 400 characters. \
                Make sure to mention the things the person needs to watch for and provide a short recommendation for the day based on the person's health. \
                Here's the data: \"\(text)\"
                """)
            ]
            
            do {
                let result = try await openAI.sendChatFour(with: chat)
                if let completion = result.choices?.first {
                    var responseText = completion.message.content
                    print("CarlosOpenAi: \(responseText)")
                    return responseText
                } else {
                    return nil
                }
            } catch {
                print("Carlos: Error fetching readiness summary: \(error)")
                return nil
            }
        }
    }
}
