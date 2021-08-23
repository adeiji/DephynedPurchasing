//
//  GRViewToursViewController+ApplePay.swift
//  Graffiti
//
//  Created by Adebayo Ijidakinro on 2/15/20.
//  Copyright © 2020 Dephyned. All rights reserved.
//

import Foundation
import UIKit
import Stripe
import PassKit

public protocol STPPaymentProtocol: UIViewController, PKPaymentAuthorizationViewControllerDelegate, STPAuthenticationContext {
    
    var paymentIntentClientSecret: String? { get set }
    
    var paymentSucceeded: Bool? { get set }
    
}

public extension STPPaymentProtocol {
    
    
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Convert the PKPayment into a PaymentMethod
        STPAPIClient.shared.createPaymentMethod(with: payment) { (paymentMethod: STPPaymentMethod?, error: Error?) in
            guard let paymentMethod = paymentMethod, error == nil else {
                // Present error to customer...
                return
            }
            guard let clientSecret = self.paymentIntentClientSecret else {
                assertionFailure("Why is the payment intent client secret nil.  That's a huge error.  Make sure you retrieve the payment intent secret first")
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }

            let paymentIntentParams = STPPaymentIntentParams(clientSecret: clientSecret)
            paymentIntentParams.paymentMethodId = paymentMethod.stripeId

            // Confirm the PaymentIntent with the payment method
            STPPaymentHandler.shared().confirmPayment(paymentIntentParams, with: self) { (status, paymentIntent, error) in
                switch (status) {
                case .succeeded:
                    // Save payment success
                    self.paymentSucceeded = true
                    completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
                case .canceled:
                    completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                case .failed:
                    // Save/handle error
                    let errors = [STPAPIClient.pkPaymentError(forStripeError: error)].compactMap({ $0 })
                    completion(PKPaymentAuthorizationResult(status: .failure, errors: errors))
                @unknown default:
                    completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                }
            }
        }
    }
    
    func authenticationPresentingViewController() -> UIViewController {
        return self
    }
}
