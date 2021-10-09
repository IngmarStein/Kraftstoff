//
//  StoreManager.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 01.09.15.
//
//

import Foundation
import Security
import StoreKit
import TPInAppReceipt

public enum StoreError: Error {
  case failedVerification
}

final class StoreManager {
  static let sharedInstance = StoreManager()

  private let twoCarsProductId = "com.github.ingmarstein.kraftstoff.iap.2cars"
  private let fiveCarsProductId = "com.github.ingmarstein.kraftstoff.iap.5cars"
  private let unlimitedCarsProductId = "com.github.ingmarstein.kraftstoff.iap.unlimitedCars"

  private var twoCarsProduct: Product!
  private var fiveCarsProduct: Product!
  private var unlimitedCarsProduct: Product!
  private var updateListenerTask: Task<Void, Error>?
  private(set) var purchasedIdentifiers = Set<String>()

  init() {
    updateListenerTask = listenForTransactions()

    Task {
      let storeProducts = try await StoreKit.Product.products(for: [twoCarsProductId, fiveCarsProductId, unlimitedCarsProductId])
      for product in storeProducts {
        switch product.id {
        case twoCarsProductId: twoCarsProduct = product
        case fiveCarsProductId: fiveCarsProduct = product
        case unlimitedCarsProductId: unlimitedCarsProduct = product
        default: break
        }
      }
    }
  }

  deinit {
    updateListenerTask?.cancel()
  }

  func listenForTransactions() -> Task<Void, Error> {
    Task.detached {
      for await result in Transaction.updates {
        do {
          let transaction = try self.checkVerified(result)
          await self.updatePurchasedIdentifiers(transaction)
          await transaction.finish()
        } catch {
          print("Transaction failed verification")
        }
      }
    }
  }

  private var maxCarCount: Int {
    fiveCars ? 5 : (twoCars ? 2 : 1)
  }

  func checkCarCount() -> Bool {
    if unlimitedCars || ProcessInfo.processInfo.arguments.firstIndex(of: "-UNLIMITED") != nil {
      return true
    }
    let carsFetchRequest = DataManager.fetchRequestForCars()
    do {
      let count = try DataManager.managedObjectContext.count(for: carsFetchRequest)
      return count == NSNotFound || count < maxCarCount
    } catch {
      return true
    }
  }

  func showBuyOptions(_ parent: UIViewController) {
    let alert = UIAlertController(title: NSLocalizedString("Car limit reached", comment: ""),
                                  message: NSLocalizedString("Would you like to buy more cars?", comment: ""), preferredStyle: .actionSheet)

    if maxCarCount < 2 {
      let twoCarsAction = UIAlertAction(title: NSLocalizedString("2 Cars", comment: ""), style: .default) { _ in
        Task {
          try? await self.purchase(self.twoCarsProduct)
        }
      }
      alert.addAction(twoCarsAction)
    }

    if maxCarCount < 5 {
      let fiveCarsAction = UIAlertAction(title: NSLocalizedString("5 Cars", comment: ""), style: .default) { _ in
        Task {
          try? await self.purchase(self.fiveCarsProduct)
        }
      }
      alert.addAction(fiveCarsAction)
    }

    let unlimitedCarsAction = UIAlertAction(title: NSLocalizedString("Unlimited Cars", comment: ""), style: .default) { _ in
      Task {
        try? await self.purchase(self.unlimitedCarsProduct)
      }
    }
    alert.addAction(unlimitedCarsAction)

    let restoreAction = UIAlertAction(title: NSLocalizedString("Restore Purchases", comment: ""), style: .default) { _ in
      SKPaymentQueue.default().restoreCompletedTransactions()
    }
    alert.addAction(restoreAction)

    let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
    alert.addAction(cancelAction)

    alert.popoverPresentationController?.sourceView = parent.view
    alert.popoverPresentationController?.sourceRect = parent.view.bounds
    alert.popoverPresentationController?.permittedArrowDirections = []
    parent.present(alert, animated: true, completion: nil)
  }

  func isPurchased(_ productIdentifier: String) async throws -> Bool {
    // Get the most recent transaction receipt for this `productIdentifier`.
    guard let result = await StoreKit.Transaction.latest(for: productIdentifier) else {
      // If there is no latest transaction, the product has not been purchased.
      return false
    }

    let transaction = try checkVerified(result)

    // Ignore revoked transactions, they're no longer purchased.

    // For subscriptions, a user can upgrade in the middle of their subscription period. The lower service
    // tier will then have the `isUpgraded` flag set and there will be a new transaction for the higher service
    // tier. Ignore the lower service tier transactions which have been upgraded.
    return transaction.revocationDate == nil && !transaction.isUpgraded
  }

  func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    // Check if the transaction passes StoreKit verification.
    switch result {
    case .unverified:
      // StoreKit has parsed the JWS but failed verification. Don't deliver content to the user.
      throw StoreError.failedVerification
    case let .verified(safe):
      // If the transaction is verified, unwrap and return it.
      return safe
    }
  }

  @MainActor
  func updatePurchasedIdentifiers(_ transaction: Transaction) async {
    if transaction.revocationDate == nil {
      // If the App Store has not revoked the transaction, add it to the list of `purchasedIdentifiers`.
      purchasedIdentifiers.insert(transaction.productID)
    } else {
      // If the App Store has revoked this transaction, remove it from the list of `purchasedIdentifiers`.
      purchasedIdentifiers.remove(transaction.productID)
    }
  }

  var twoCars: Bool {
    purchasedIdentifiers.contains(twoCarsProductId)
  }

  var fiveCars: Bool {
    purchasedIdentifiers.contains(fiveCarsProductId)
  }

  var unlimitedCars: Bool {
    purchasedIdentifiers.contains(unlimitedCarsProductId)
  }

  func purchase(_ product: Product) async throws -> Transaction? {
    // Begin a purchase.
    let result = try await product.purchase()

    switch result {
    case let .success(verification):
      let transaction = try checkVerified(verification)

      // Deliver content to the user.
      // await updatePurchasedIdentifiers(transaction)

      // Always finish a transaction.
      await transaction.finish()

      return transaction
    case .userCancelled, .pending:
      return nil
    default:
      return nil
    }
  }
}
