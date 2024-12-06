//
//  SubscriptionManager.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 12/2/24.
//

import StoreKit

class SubscriptionManager {
    static let shared = SubscriptionManager()

    private init() {}

    func isSubscriptionValid() async -> Bool {
        do {
            // Fetch products by their IDs
            let productIds = ["monthly", "yearly"]
            let products = try await Product.products(for: productIds)

            for product in products {
                if let subscription = product.subscription {
                    // Fetch the current entitlement asynchronously
                    if let entitlement = await product.currentEntitlement {
                        // Verify the transaction
                        switch entitlement {
                        case .verified(let transaction):
                            // Check if the transaction is active
                            if transaction.expirationDate ?? Date.distantPast > Date() {
                                return true // Valid subscription exists
                            }
                        case .unverified:
                            print("Unverified transaction for product: \(product.id)")
                        }
                    }
                }
            }

            return false // No valid subscription found
        } catch {
            print("Error checking subscription: \(error)")
            return false
        }
    }

    func restorePurchase() async throws {
        do {
            try await AppStore.sync()
            print("Restored purchases successfully.")
        } catch {
            throw error
        }
    }
}
