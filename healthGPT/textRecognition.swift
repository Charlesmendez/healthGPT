//
//  textRecognition.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 12/20/23.
//

import Foundation

final class TextRecognition {
    // ... Your existing functions ...

    func findCommonalitiesInArray(keywords: [String], textHandler: @escaping (_ textClassifier: String?) -> Void) {
        if keywords.count == 1 {
            textHandler(keywords.first)
        } else {
            let text = keywords.joined(separator: ", ") // Join sleep data keywords
            print(text)
            
            var apiKey: String?
            if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
                apiKey = dict["APIKey"] as? String
            }
            
            guard let apiKey = apiKey else {
                print("API Key not found")
                textHandler(nil)
                return
            }
            let openAI = OpenAISwift(authToken: apiKey)

            let chat: [ChatMessage] = [
                ChatMessage(role: .system, content: "You are a helpful doctor."),
                ChatMessage(role: .user, content: "Examine each data point and give me a readiness score between 0 and 100. For example 'Your readiness score is 85'. The score can be part of a summary of maximum 180 characters. Here's the data: \"\(text)\"")
            ]

            Task {
                do {
                    let result = try await openAI.sendChatFour(with: chat, maxTokens: 50)
                    if let completion = result.choices?.first {
                        var responseText = completion.message.content

                        // Uppercase the first word
                        responseText = responseText

                        textHandler(responseText)
                    } else {
                        textHandler(nil)
                    }
                } catch {
                    textHandler(nil)
                }
            }
        }
    }

    // ... Your existing extensions ...
}

