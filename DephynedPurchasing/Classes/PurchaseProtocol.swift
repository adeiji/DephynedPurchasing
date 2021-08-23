//
//  PurchaseProtocol.swift
//  Graffiti
//
//  Created by Adebayo Ijidakinro on 2/13/20.
//  Copyright © 2020 Dephyned. All rights reserved.
//

import Foundation
import StoreKit
import PassKit

public protocol PurchaseProtocol {
        
}

public extension PurchaseProtocol  {
            
    /**
     Loads all the available products from apple servers.  Make sure that you store this result somewhere
     
     - parameter completion: Returns all the products from the Apple servers that have the ids that you inputed when initializing
     the PKIAPHandler object
     */
    private func loadProducts (completion: @escaping ([SKProduct]) -> Void) {
        PKIAPHandler.shared.fetchAvailableProducts { (products) in
            completion(products)
        }
    }
        
    /**
     Given a list of products, returns the product with the given Id
     
     - parameters:
        - id: The id of the product you want
        - products: The list of products to filter through
     */
    private func getProductWithId (id: String, products: [SKProduct]) -> SKProduct? {
        return products.filter { $0.productIdentifier == id }.first
    }
    
    /**
     Purchases a product with the given Id
     - parameter id: The id of the proudct to purchase
     - parameter completion: Returns whether or not the purchase was successful
     */
    func purchaseProductWithId(id: String, completion: @escaping (Bool, PKIAPHandlerAlertType) -> Void) {
        self.loadProducts { (products) in
            guard let product = self.getProductWithId(id: id, products: products) else {
                return
            }
            
            self.purchaseProduct(product: product) { (success, alertType) in
                if success {
                    completion(success, alertType)
                } else {
                    completion(false, alertType)
                }
            }
        }
    }
    
    /**
     Purchase a product
     */
    private func purchaseProduct (product: SKProduct, completion: @escaping (Bool, PKIAPHandlerAlertType) -> ()) {
        PKIAPHandler.shared.purchase(product: product) { (alertType, product, transaction) in
            // If product and transaction were both not nil that means that the purchase was a success
            if let _ = product, let _ = transaction {
                completion(true, alertType)
            } else {
                completion(false, alertType)
            }
        }
    }
}
