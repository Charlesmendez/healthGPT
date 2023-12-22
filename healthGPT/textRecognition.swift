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

            let apiKey = "YOUR API KEY" // Replace with your OpenAI API key
            let openAI = OpenAISwift(authToken: apiKey)

            let chat: [ChatMessage] = [
                ChatMessage(role: .system, content: "You are a helpful doctor."),
                ChatMessage(role: .user, content: "Examine each data point and give me a readiness score between 0 and 100. For example 'Your readiness score is 85'. The score can be part of a summary of maximum 100 characters. Here's the data: \"\(text)\"")
            ]

            Task {
                do {
                    let result = try await openAI.sendChatFour(with: chat, maxTokens: 50)
                    if let completion = result.choices?.first {
                        var responseText = completion.message.content

                        // Uppercase the first word
                        responseText = responseText

                        // Remove any special characters and dots from the entire string
                        responseText = responseText.filter { !$0.unicodeScalars.contains(where: CharacterSet.punctuationCharacters.contains) }

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

