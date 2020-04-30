//
//  StripeManager.swift
//  Graffiti
//
//  Created by Adebayo Ijidakinro on 2/13/20.
//  Copyright © 2020 Dephyned. All rights reserved.
//

import Foundation
import Stripe
import RxSwift
import RxCocoa

enum HttpMethod:String, CustomStringConvertible {
    case GET = "GET"
    case POST = "POST"
    case UPDATE = "UPDATE"
    
    var description: String {
        return self.rawValue
    }
}

class StripeManager: NSObject {

    
    var paymentSucceeded = false
    
    let disposeBag = DisposeBag()
    var paymentIntentClientSecret:String?
    
    /**
     Payment intents are necessary for any kind of payment.  First you get the client secret from a payment intent, and then you can make the charge.  The amount needs to be stored in a document with a key of "price" in order for this to work
     
     - parameters:
        - collection: The collection for the item being purchased, needs to contain price
        - documentId: The id of the document that contains the price
    */
    func getPaymentIntent (collection:String, documentId:String) -> Observable<Bool> {
        
        #if DEBUG
        let url = "https://graffitisocial.herokuapp.com/paymentIntent"
        #else
        let url = "https://graffitisocialprod.herokuapp.com/paymentIntent"
        #endif
        
        return Observable.create { (observer) -> Disposable in
            NetworkManager.getRequest(urlString: url, body: ["collection": collection, "documentId": documentId], httpMethod: .POST ).subscribe(onNext: { (json) in
                
                // If the client secret was successfully returned then it was a success, otherwise it was not
                if let clientSecret = json["clientSecret"] as? String {
                    self.paymentIntentClientSecret = clientSecret
                    observer.onNext(true)
                    observer.onCompleted()
                } else {
                    observer.onNext(false)
                    observer.onCompleted()
                }
                
            }, onError: { error in
                observer.onNext(false)
            }).disposed(by: self.disposeBag)
            
            return Disposables.create()
        }
    }
    
    /**
     Pay for a service, using the client secret
     */
    func pay(cardParams: STPPaymentMethodCardParams, authViewController:STPAuthenticationContext, completion: @escaping (Bool) -> Void){
        guard let paymentIntentClientSecret = self.paymentIntentClientSecret else {
            assertionFailure("The payment intent client secret is non-existent.  Which means the step of getting the payment intent failed or you've called this method prematurely")
            return
        }
        
        // Collect card details
        let paymentMethodParams = STPPaymentMethodParams(card: cardParams, billingDetails: nil, metadata: nil)
        let paymentIntentParams = STPPaymentIntentParams(clientSecret: paymentIntentClientSecret)
        paymentIntentParams.paymentMethodParams = paymentMethodParams

        // Submit the payment
        let paymentHandler = STPPaymentHandler.shared()
        paymentHandler.confirmPayment(withParams: paymentIntentParams, authenticationContext: authViewController) { (status, paymentIntent, error) in
            switch (status) {
            case .failed:
                completion(false)
                break
            case .canceled:
                completion(false)
                break
            case .succeeded:                
                completion(true)
                break
            @unknown default:
                assertionFailure()
                completion(false)
                break
            }
        }
    }
    
}

class NetworkManager {
    
    class func getRequest (urlString:String, body: [String:Any], httpMethod:HttpMethod) -> Observable<[String:Any]> {
        
        guard let url = URL(string: urlString) else {
            assertionFailure("This url does not exist")
            return .empty()
        }
        
        return Observable.create { (observer) -> Disposable in
            //create the session object
            let session = URLSession.shared

            //now create the URLRequest object using the url object
            var request = URLRequest(url: url)
            request.httpMethod = httpMethod.rawValue
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed)
            } catch {
                assertionFailure("Not able to serialize the body parameter")
            }

            //create dataTask using the session object to send data to the server
            let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in

                if let error = error {
                    observer.onError(error)
                    return
                }

                guard let data = data else {
                    return
                }

               do {
                  //create json object from data
                  if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    observer.onNext(json)
                    observer.onCompleted()
                  }
               } catch let error {
                 print(error.localizedDescription)
               }
            })

            task.resume()
            return Disposables.create()
        }
        
    }
    
}
