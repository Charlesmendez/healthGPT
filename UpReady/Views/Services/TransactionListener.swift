//
//  TransactionListener.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 12/2/24.
//

import SwiftUI
import StoreKit

@MainActor
class TransactionListener: ObservableObject {
    private var updatesTask: Task<Void, Never>?

    func startListening() {
        // Prevent multiple listeners
        guard updatesTask == nil else { return }

        updatesTask = Task {
            for await verification in Transaction.updates {
                switch verification {
                case .verified(let transaction):
                    print("Transaction verified: \(transaction.productID)")
                    await transaction.finish() // Mark the transaction as complete
                case .unverified(_, let error):
                    print("Transaction unverified: \(error.localizedDescription)")
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }
}
