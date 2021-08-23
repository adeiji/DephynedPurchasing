//
//  PKIAPHandler.swift
//
//
import UIKit
import StoreKit

extension Notification.Name {
    public static let DEPurchaseFailed = NSNotification.Name("PurchaseFailed")
    public static let DERestorePurchaseFailed = NSNotification.Name("RestorePurchaseFailed")
}

public enum PKIAPHandlerAlertType {
    case setProductIds
    case disabled
    case restored
    case purchased
    case error
    case canceled
    
    var message: String{
        switch self {
        case .setProductIds: return "Product ids not set, call setProductIds method!"
        case .disabled: return "Purchases are disabled in your device!"
        case .restored: return "You've successfully restored your purchase!"
        case .purchased: return "You've successfully bought this purchase!"
        case .canceled: return "You canceled!"
        case .error: return "Error with purchase"
        }
    }
}

public class PKIAPHandler: NSObject, SKPaymentQueueDelegate {
    
    public override init () {
        super.init()
        if #available(iOS 13.0, *) {
            SKPaymentQueue.default().delegate = self
        } else {
            // Fallback on earlier versions
        }
        
        self.setValidPurchases()
    }
    
    public func setValidPurchases () {
        self.getValidPurchases { (validPurchases) in
            self.validPurchases = validPurchases
        }
    }
    
    //MARK:- Properties
    //MARK:- Private
    public static let shared = PKIAPHandler()
    
    fileprivate var productIds = [String]()
    fileprivate var productID = ""
    fileprivate var productsRequest = SKProductsRequest()
    fileprivate var fetchProductCompletion: (([SKProduct])->Void)?
    
    fileprivate var productToPurchase: SKProduct?
    fileprivate var purchaseProductCompletion: ((PKIAPHandlerAlertType, SKProduct?, SKPaymentTransaction?)->Void)?
    
    fileprivate var hasReceiptData:Bool = false
    fileprivate var isSubscriptionExpired = true
    
    public var validPurchases:[String?] = []
    
    //MARK:- Public
    var isLogEnabled: Bool = true
    
    //MARK:- Methods
    //MARK:- Public
    
    public func purchaseIsValid (purchaseId: String) -> Bool {
        
        if self.validPurchases.contains(purchaseId) {
            return true
        }
        
        return false
    }
    
    //Set Product Ids
    public func setProductIds(ids: [String]) {
        self.productIds = ids
    }
    
    //MAKE PURCHASE OF A PRODUCT
    public func canMakePurchases() -> Bool {  return SKPaymentQueue.canMakePayments()  }
    
    public func loadProductIds (_ productIds:[String]) {
        self.productIds = productIds
    }
    
    public func purchase(product: SKProduct, Completion: @escaping ((PKIAPHandlerAlertType, SKProduct?, SKPaymentTransaction?)->Void)) {
        
        self.purchaseProductCompletion = Completion
        self.productToPurchase = product
        
        if self.canMakePurchases() {            
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(self)
            SKPaymentQueue.default().add(payment)
            log("PRODUCT TO PURCHASE: \(product.productIdentifier)")
            productID = product.productIdentifier
        }
        else {
            Completion(PKIAPHandlerAlertType.disabled, nil, nil)
        }
    }
    
    // RESTORE PURCHASE
    public func restorePurchase(completion: @escaping ((PKIAPHandlerAlertType, SKProduct?, SKPaymentTransaction?)->Void)){
        self.purchaseProductCompletion = completion
        SKPaymentQueue.default().add(self)
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    
    // FETCH AVAILABLE IAP PRODUCTS
    public func fetchAvailableProducts(Completion: @escaping (([SKProduct])->Void)){
        
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
    
    public func verifyReceipt (verifyReceiptURL: URL? = nil, completion: ((NSDictionary?) -> Void)? = nil) {
        if let receiptUrl = Bundle.main.appStoreReceiptURL {
            let receipt = try? Data(contentsOf: receiptUrl, options: .alwaysMapped)
            if receipt == nil {
                // Error
                return
            }
            
            let receiptData = receipt?.base64EncodedString(options: [NSData.Base64EncodingOptions.endLineWithCarriageReturn])
            
            let receiptDictionary = ["receipt-data": receiptData, "password": "4e0c1a8270a447948ff4d8dcda6be109"]
            let requestData = try? JSONSerialization.data(withJSONObject: receiptDictionary, options: .prettyPrinted)
            
            let url = verifyReceiptURL  ?? URL(string: "https://buy.itunes.apple.com/verifyReceipt")
                        
            if let url = url {
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpMethod = "POST"
                request.httpBody = requestData
                
                let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                    print("This is the response from \(url) -  \(response)")
                    guard let data = data, error == nil else {
                        if let completion = completion {
                            completion(nil)
                        }
                        
                        return
                    }
                    
                    if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? NSDictionary {
                        self.hasReceiptData = true
                        if (jsonResponse["status"] as? Int == 21007) {
                            self.verifyReceipt(verifyReceiptURL: URL(string: "https://sandbox.itunes.apple.com/verifyReceipt"), completion: completion)
                            return
                        }
                        
                        if let expirationDate = self.expirationDateFromResponse(jsonResponse: jsonResponse) {
                            self.updateIAPExpirationDate(expirationDate: expirationDate)
                        }
                        
                        if let completion = completion {
                            completion(jsonResponse)
                        }
                    }
                }
                
                task.resume()
            }
        }
    }
    
    public func updateIAPExpirationDate (expirationDate: Date) {
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
    
    public func expirationDateFromResponse(jsonResponse: NSDictionary?) -> Date? {
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
    
    private func getValidPurchases (completion: @escaping ([String?]) -> Void) {
        
        self.verifyReceipt { [weak self] (response) in
            guard let _ = self else { return }
            
            guard let response = response else {
                completion([])
                return
            }
            
            // Get the actual receipt information
            let receipt = response.object(forKey: "receipt") as? NSDictionary
            
            // Get a dictionary of all the purchases that have not expired
            let purchases = (receipt?.object(forKey: "in_app") as? [NSDictionary])?.filter({ (purchase) -> Bool in
                // Get the date that this product was purchased in milliseconds
                guard let purchaseDateInMsString = purchase.object(forKey: "expires_date_ms") as? String else { return false }
                guard let purchaseDateInMs = TimeInterval(purchaseDateInMsString) else { return false }
                // Create a date object of the purchase date
                let purchaseDate = Date(timeIntervalSince1970: purchaseDateInMs)
                let currentDate = Date()
                
                // Check to see if this product has already expired
                if (purchaseDate < currentDate) {
                    return false
                }
                
                // This product is still valid
                return true
            })
            
            completion(purchases?.map({ $0.object(forKey: "product_id") as? String }) ?? [])
        }
    }
}

//MARK:- Product Request Delegate and Payment Transaction Methods
//MARK:-
extension PKIAPHandler: SKProductsRequestDelegate, SKPaymentTransactionObserver{
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .DEPurchaseFailed, object: nil)
        }
    }
    
    // REQUEST IAP PRODUCTS
    public func productsRequest (_ request:SKProductsRequest, didReceive response:SKProductsResponse) {
        if (response.products.count > 0) {
            if let Completion = self.fetchProductCompletion {
                Completion(response.products)
            }
        }
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        if let completion = self.purchaseProductCompletion {
            completion(PKIAPHandlerAlertType.restored, nil, nil)
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        if let completion = self.purchaseProductCompletion {
            print(error.localizedDescription)
            completion(PKIAPHandlerAlertType.error, nil, nil)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .DERestorePurchaseFailed, object: nil, userInfo: ["error": error.localizedDescription])
        }
    }
    
    /**
     Whenever the user purchases we want to save that purchase so that we can check quickly locally whether or not the user has purchased this item.
     */
    private func saveProductIdAsPurchased (_ id: String) {
        let userDefaults = UserDefaults()
        userDefaults.set(true, forKey: id)
        userDefaults.synchronize()
    }
    
    // Returns whether this user has purchased the product with this id
    public func productIsPurchased (_ id: String) -> Bool {
        let userDefaults = UserDefaults()
        return userDefaults.object(forKey: id) as? Bool ?? false
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
                        guard let productId = self.productToPurchase?.productIdentifier else { return }
                        self.saveProductIdAsPurchased(productId)
                        PKIAPHandler.shared.setValidPurchases()
                    }
                    break
                    
                case .failed:
                    log("Product purchase failed")
                    SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
                    if let Completion = self.purchaseProductCompletion {
                        Completion(PKIAPHandlerAlertType.canceled, self.productToPurchase, trans)
                        PKIAPHandler.shared.setValidPurchases()
                    }
                    break
                case .restored:
                    log("Product restored")
                    SKPaymentQueue.default().finishTransaction(
                        transaction as! SKPaymentTransaction)
                    if let Completion = self.purchaseProductCompletion {
                        Completion(PKIAPHandlerAlertType.restored, self.productToPurchase, trans)
                        PKIAPHandler.shared.setValidPurchases()
                    }
                    guard let productId = self.productToPurchase?.productIdentifier else { return }
                    self.saveProductIdAsPurchased(productId)
                    break
                    
                default: break
                }
            }            
        }
    }
}
