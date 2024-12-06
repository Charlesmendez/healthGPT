//
//  PaywallView.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 12/2/24.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: String? = nil
    @State private var isRestoring = false
    @State private var products: [Product] = [] // StoreKit products
    let onRestore: () -> Void // Callback to restore purchases
    let onComplete: () -> Void // Callback when subscription is complete
    let onBackToSignIn: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Image with Overlay
                ZStack {
                    Image("rise")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.3),
                                    Color.black.opacity(0.6)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    VStack {
                        Spacer()
                        Text("Rise and Shine")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                            .padding(.bottom, 40)
                    }
                }
                
                // Title and Subtitle with Trial Mention
                VStack(spacing: 10) {
                    Text("Level Up Your Readiness")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Start with a **7-day free trial** and choose a plan to unlock premium features.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .fixedSize(horizontal: false, vertical: true) // Allows multi-line
                }
                .padding(.horizontal, 20)
                
                // Subscription Cards
                VStack(spacing: 20) {
                    ForEach(products, id: \.id) { product in
                        SubscriptionCard(
                            title: product.displayName,
                            price: product.displayPrice,
                            subtitle: product.id == "yearly" ? "20% OFF" : nil,
                            trialPeriod: "7-day free trial",
                            isSelected: selectedPlan == product.id
                        ) {
                            withAnimation(.spring()) {
                                selectedPlan = product.id
                            }
                        }
                        .shadow(color: Color.primary.opacity(0.1), radius: 5, x: 0, y: 5)
                    }
                }
                .padding(.horizontal, 20)
                
                // Continue Button
                if let selectedPlan = selectedPlan {
                    Button(action: {
                        purchaseSubscription(planID: selectedPlan)
                    }) {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: Color.green.opacity(0.4), radius: 5, x: 0, y: 5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .transition(.opacity)
                }
                
                // Restore Purchases Button
                Button(action: {
                    isRestoring = true
                    onRestore()
                    isRestoring = false
                }) {
                    Text("Restore Purchases")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .underline()
                }
                .padding(.top, 10)
                
                Spacer()
                
                // Back to Sign In
                Button(action: {
                    onBackToSignIn()
                }) {
                    Text("Back to Sign In")
                        .font(.footnote)
                        .underline()
                        .foregroundColor(.primary)
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
        .task {
            await fetchProducts()
        }
    }

    private func fetchProducts() async {
        do {
            let productIDs = ["yearly", "monthly"] // Ensure your desired order here
            var fetchedProducts = try await Product.products(for: productIDs)
            
            // Sort the fetched products based on the order in productIDs
            fetchedProducts.sort { first, second in
                guard let firstIndex = productIDs.firstIndex(of: first.id),
                      let secondIndex = productIDs.firstIndex(of: second.id) else {
                    return false
                }
                return firstIndex < secondIndex
            }
            
            products = fetchedProducts
        } catch {
            print("Failed to fetch products: \(error.localizedDescription)")
        }
    }
    
    private func purchaseSubscription(planID: String) {
        Task {
            do {
                guard let product = products.first(where: { $0.id == planID }) else {
                    print("Product not found for ID: \(planID)")
                    return
                }
                
                // Initiate the purchase
                let result = try await product.purchase()
                
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        print("Purchase successful for product ID: \(transaction.productID)")
                        await transaction.finish()
                        onComplete() // Call the completion handler to update UI or state
                    case .unverified(_, let error):
                        print("Purchase verification failed: \(error.localizedDescription ?? "Unknown error")")
                    }
                    
                case .userCancelled:
                    print("User canceled the purchase.")
                    
                case .pending:
                    print("Purchase pending.")
                @unknown default:
                    print("Unknown default")
                }
            } catch {
                print("Purchase failed: \(error.localizedDescription)")
            }
        }
    }
}

struct SubscriptionCard: View {
    let title: String
    let price: String
    let subtitle: String?
    let trialPeriod: String? // New property for trial
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? Color.green.opacity(0.1) : Color(UIColor.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(isSelected ? Color.green : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
                
                VStack(alignment: .leading, spacing: 10) {
                    // Trial Badge
                    if let trial = trialPeriod {
                        Text(trial)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Subtitle (e.g., "20% OFF")
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(5)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    Spacer()
                    
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? Color.green : .primary)
                    
                    Text(price)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? Color.green : .primary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 140) // Increased height to accommodate trial badge
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaywallView(
                onRestore: {},
                onComplete: {},
                onBackToSignIn: {}
            )
            .preferredColorScheme(.light)
            
            PaywallView(
                onRestore: {},
                onComplete: {},
                onBackToSignIn: {}
            )
            .preferredColorScheme(.dark)
        }
    }
}
