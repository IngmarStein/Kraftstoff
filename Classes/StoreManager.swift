//
//  StoreManager.swift
//  Kraftstoff
//
//  Created by Ingmar Stein on 01.09.15.
//
//

import Foundation
import StoreKit

class StoreManager : NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
	static let sharedInstance = StoreManager()

	private let twoCarsProductId = "com.github.ingmarstein.kraftstoff.2cars"
	private let fiveCarsProductId = "com.github.ingmarstein.kraftstoff.5cars"
	private let unlimitedCarsProductId = "com.github.ingmarstein.kraftstoff.unlimitedCars"
	private let purchasedProductsKey = "purchasedProducts"

	override init() {
		super.init()

		SKPaymentQueue.defaultQueue().addTransactionObserver(self)
	}

	private var maxCarCount : Int {
		return fiveCars ? 5 : (twoCars ? 2 : 1)
	}

	func checkCarCount() -> Bool {
		let moc = CoreDataManager.managedObjectContext
		let carsFetchRequest = CoreDataManager.fetchRequestForCarsInManagedObjectContext(moc)
		let count = moc.countForFetchRequest(carsFetchRequest, error: nil)
		return count == NSNotFound || unlimitedCars || count < maxCarCount
	}

	func showBuyOptions(parent: UIViewController) {
		let alert = UIAlertController(title: NSLocalizedString("Car limit reached", comment: ""),
			message: NSLocalizedString("Would you like to buy more cars?", comment: ""), preferredStyle: .ActionSheet)

		if maxCarCount < 2 {
			let twoCarsAction = UIAlertAction(title: NSLocalizedString("2 Cars", comment: ""), style: .Default) { _ in
				self.buyProduct(self.twoCarsProductId)
			}
			alert.addAction(twoCarsAction)
		}

		if maxCarCount < 5 {
			let fiveCarsAction = UIAlertAction(title: NSLocalizedString("5 Cars", comment: ""), style: .Default) { _ in
				self.buyProduct(self.fiveCarsProductId)
			}
			alert.addAction(fiveCarsAction)
		}

		let unlimitedCarsAction = UIAlertAction(title: NSLocalizedString("Unlimited Cars", comment: ""), style: .Default) { _ in
			self.buyProduct(self.unlimitedCarsProductId)
		}
		alert.addAction(unlimitedCarsAction)

		let restoreAction = UIAlertAction(title: NSLocalizedString("Restore Purchases", comment: ""), style: .Default) { _ in
			SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
		}
		alert.addAction(restoreAction)

		let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: nil)
		alert.addAction(cancelAction)

		alert.popoverPresentationController?.sourceView = parent.view
		alert.popoverPresentationController?.sourceRect = parent.view.bounds
		alert.popoverPresentationController?.permittedArrowDirections = .allZeros
		parent.presentViewController(alert, animated: true, completion: nil)
	}

	private func isProductPurchased(product: String) -> Bool {
		if let purchasedProducts = NSUserDefaults.standardUserDefaults().arrayForKey(purchasedProductsKey) as? [String] {
			return find(purchasedProducts, product) != nil
		}
		return false
	}

	private func setProductPurchased(product: String, purchased: Bool) {
		let userDefaults = NSUserDefaults.standardUserDefaults()
		var purchasedProducts = (userDefaults.arrayForKey(purchasedProductsKey) as? [String]) ?? [String]()
		let index = find(purchasedProducts, product)
		if purchased {
			if index == nil {
				purchasedProducts.append(product)
			}
		} else {
			if let index = index {
				purchasedProducts.removeAtIndex(index)
			}
		}
		userDefaults.setObject(purchasedProducts, forKey: purchasedProductsKey)
		userDefaults.synchronize()
	}

	var twoCars : Bool {
		return isProductPurchased(twoCarsProductId)
	}

	var fiveCars : Bool {
		return isProductPurchased(fiveCarsProductId)
	}

	var unlimitedCars : Bool {
		return isProductPurchased(unlimitedCarsProductId)
	}

	private func buyProduct(productIdentifier: String) {
		if SKPaymentQueue.canMakePayments() {
			let productsRequest = SKProductsRequest(productIdentifiers: [productIdentifier])
			productsRequest.delegate = self
			productsRequest.start()
		}
	}

	func productsRequest(request: SKProductsRequest!, didReceiveResponse response: SKProductsResponse!) {
		if let product = response.products.first as? SKProduct where response.products.count == 1 {
			var payment = SKPayment(product: product)
			SKPaymentQueue.defaultQueue().addPayment(payment)
		}
	}

	func paymentQueue(queue: SKPaymentQueue!, updatedTransactions transactions: [AnyObject]!) {
		for transaction in transactions {
			if let transaction = transaction as? SKPaymentTransaction {
				switch transaction.transactionState {
				case .Purchased, .Restored:
					setProductPurchased(transaction.payment.productIdentifier, purchased: true)
					SKPaymentQueue.defaultQueue().finishTransaction(transaction)
				case .Failed:
					SKPaymentQueue.defaultQueue().finishTransaction(transaction)
					println("Transaction failed: \(transaction.error)")
				default: ()
				}
			}
		}
	}
}
