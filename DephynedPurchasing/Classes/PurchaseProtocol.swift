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
    
    /**
     When initializing this object make sure that you give it a list of product ids for your app
     For more information on this view: https://developer.apple.com/library/archive/qa/qa1329/_index.html
     */
    var pkIapHandler:PKIAPHandler { get }
    
}

public extension PurchaseProtocol  {
            
    /**
     Loads all the available products from apple servers.  Make sure that you store this result somewhere
     
     - parameter completion: Returns all the products from the Apple servers that have the ids that you inputed when initializing
     the PKIAPHandler object
     */
    private func loadProducts (completion: @escaping ([SKProduct]) -> Void) {
        self.pkIapHandler.fetchAvailableProducts { (products) in
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
    func purchaseProductWithId(id: String, completion: @escaping (Bool) -> Void) {        
        self.loadProducts { (products) in
            guard let product = self.getProductWithId(id: id, products: products) else {
                return
            }
            
            self.purchaseProduct(product: product) { (success) in
                if success {
                    completion(success)
                }
            }
        }
    }
    
    /**
     Purchase a product
     */
    private func purchaseProduct (product: SKProduct, completion: @escaping (Bool) -> ()) {
        self.pkIapHandler.purchase(product: product) { (alertType, product, transaction) in
            // If product and transaction were both not nil that means that the purchase was a success
            if let _ = product, let _ = transaction {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
}
