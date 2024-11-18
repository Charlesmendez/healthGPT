//
//  FriendsView.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct FriendsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Friends")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()

                // Placeholder content for Friends
                List {
                    ForEach(1...10, id: \.self) { index in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            
                            Text("Friend \(index)")
                                .font(.headline)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .navigationBarTitle("Friends", displayMode: .inline)
        }
    }
}
