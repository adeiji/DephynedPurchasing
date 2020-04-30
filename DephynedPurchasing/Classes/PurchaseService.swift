//
//  PKIAPHandler.swift
//
//
import UIKit
import StoreKit

enum PKIAPHandlerAlertType {
    case setProductIds
    case disabled
    case restored
    case purchased
    
    var message: String{
        switch self {
        case .setProductIds: return "Product ids not set, call setProductIds method!"
        case .disabled: return "Purchases are disabled in your device!"
        case .restored: return "You've successfully restored your purchase!"
        case .purchased: return "You've successfully bought this purchase!"
        }
    }
}


public class PKIAPHandler: NSObject {
    
    init (productIds:[String]) {
        super.init()
        self.productIds = productIds
    }
    
    //MARK:- Properties
    //MARK:- Private
    fileprivate var productIds = [String]()
    fileprivate var productID = ""
    fileprivate var productsRequest = SKProductsRequest()
    fileprivate var fetchProductCompletion: (([SKProduct])->Void)?
    
    fileprivate var productToPurchase: SKProduct?
    fileprivate var purchaseProductCompletion: ((PKIAPHandlerAlertType, SKProduct?, SKPaymentTransaction?)->Void)?
    
    fileprivate var hasReceiptData:Bool = false
    fileprivate var isSubscriptionExpired = true
    
    //MARK:- Public
    var isLogEnabled: Bool = true
    
    //MARK:- Methods
    //MARK:- Public
    
    //Set Product Ids
    func setProductIds(ids: [String]) {
        self.productIds = ids
    }
    
    //MAKE PURCHASE OF A PRODUCT
    func canMakePurchases() -> Bool {  return SKPaymentQueue.canMakePayments()  }
    
    func purchase(product: SKProduct, Completion: @escaping ((PKIAPHandlerAlertType, SKProduct?, SKPaymentTransaction?)->Void)) {
        
        self.purchaseProductCompletion = Completion
        self.productToPurchase = product
        
        if self.canMakePurchases() {
            let payment = SKPayment(product: product)
//            SKPaymentQueue.default().add(self)
            SKPaymentQueue.default().add(payment)
            
            log("PRODUCT TO PURCHASE: \(product.productIdentifier)")
            productID = product.productIdentifier
        }
        else {
            Completion(PKIAPHandlerAlertType.disabled, nil, nil)
        }
    }
    
    // RESTORE PURCHASE
    func restorePurchase(){
        SKPaymentQueue.default().add(self)
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    
    // FETCH AVAILABLE IAP PRODUCTS
    func fetchAvailableProducts(Completion: @escaping (([SKProduct])->Void)){
        
        self.fetchProductCompletion = Completion
        // Put here your IAP Products ID's
        if self.productIds.isEmpty {
            log(PKIAPHandlerAlertType.setProductIds.message)
            fatalError(PKIAPHandlerAlertType.setProductIds.message)
        }
        else {
            productsRequest = SKProductsRequest(productIdentifiers: Set(self.productIds))
            productsRequest.delegate = self
            productsRequest.start()
        }
    }
    
    //MARK:- Private
    fileprivate func log <T> (_ object: T) {
        if isLogEnabled {
            NSLog("\(object)")
        }
    }
    
    func uploadReceipt (completion: ((Bool?) -> Void)? = nil) {
        if let receiptUrl = Bundle.main.appStoreReceiptURL {
            let receipt = try? Data(contentsOf: receiptUrl)
            if receipt == nil {
                // Error
                return
            }
            
            let receiptDictionary = ["receipt-data": receipt?.base64EncodedString(options: []), "password": "9df62b8245de418fbf16c5298a366868"]
            let requestData = try? JSONSerialization.data(withJSONObject: receiptDictionary, options: .prettyPrinted)
            if let url = URL(string: "https://buy.itunes.apple.com/verifyReceipt") {
                var request = URLRequest(url: url)
                request.setValue("application/application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpMethod = "POST"
                request.httpBody = requestData
                
                let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                    guard let data = data, error == nil else {
                        if let completion = completion {
                            completion(false)
                        }
                        
                        return
                    }
                    
                    if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? NSDictionary {
                        self.hasReceiptData = true
                        if let expirationDate = self.expirationDateFromResponse(jsonResponse: jsonResponse) {
                            self.updateIAPExpirationDate(expirationDate: expirationDate)
                        }
                        
                        if let completion = completion {
                            completion(true)
                        }
                    }
                }
                
                task.resume()
            }
        }
    }
    
    func updateIAPExpirationDate (expirationDate: Date) {
        let expDateKey = "expDate"
        let userDefaults = UserDefaults.standard
        if let previousExpDate = userDefaults.object(forKey: expDateKey) as? Date {
            
            if expirationDate.timeIntervalSince(Date()) > 0 {
                self.isSubscriptionExpired = false
            }
            
            // The subscription has been renewed
            if previousExpDate.timeIntervalSince(expirationDate) < 0 {
                userDefaults.set(expirationDate, forKey: expDateKey)
            }
            
            if previousExpDate.timeIntervalSince(expirationDate) > 0 {
                // Subscription has expired, most likely cancelled
            }
        } else {
            userDefaults.set(expirationDate, forKey: expDateKey)
            userDefaults.synchronize()
        }
    }
    
    func expirationDateFromResponse(jsonResponse: NSDictionary?) -> Date? {
        if let jsonResponse = jsonResponse {
            if let receiptInfo: NSArray = jsonResponse["latest_receipt_info"] as? NSArray {
                let lastReceipt = receiptInfo.lastObject as! NSDictionary
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"
                let expirationDate = formatter.date(from: lastReceipt["expires_date"] as! String) as Date?
                return expirationDate
            } else {
                return nil
            }
        } else {
            return nil
        }
        
    }
}

//MARK:- Product Request Delegate and Payment Transaction Methods
//MARK:-
extension PKIAPHandler: SKProductsRequestDelegate, SKPaymentTransactionObserver{
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        
    }
    
    // REQUEST IAP PRODUCTS
    public func productsRequest (_ request:SKProductsRequest, didReceive response:SKProductsResponse) {
        if (response.products.count > 0) {
            if let Completion = self.fetchProductCompletion {
                Completion(response.products)
            }
        }
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        if let completion = self.purchaseProductCompletion {
            completion(PKIAPHandlerAlertType.restored, nil, nil)
        }
    }
    
    // IAP PAYMENT QUEUE
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction:AnyObject in transactions {
            if let trans = transaction as? SKPaymentTransaction {
                switch trans.transactionState {
                case .purchased:
                    log("Product purchase done")
                    SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
                    if let Completion = self.purchaseProductCompletion {
                        Completion(PKIAPHandlerAlertType.purchased, self.productToPurchase, trans)
                    }
                    break
                    
                case .failed:
                    log("Product purchase failed")
                    SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
                    break
                case .restored:
                    log("Product restored")
                    SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
                    break
                    
                default: break
                }
            }            
        }
    }
}
