# DephynedPurchasing
This library makes it very easy to integrate Stripe and PurchaseKit into your iOS Swift applications

There are two ways that you can handle purchasing, and that's InApp Purchasing through the Apple App Store, or by using Stripe.  Make sure when using Stripe though that the product meets Apple's guidelines as an item that can be purchased not using In-App purchases otherwise Apple will reject your app.

## In-App Purchasing

First make sure you implmenent the Purchase Protocol which will give you access to the necessary functions

```
class YourViewController: PurchaseProtocol
```

#### Getting Your Product Ids
````
If you have not created your products yet using AppStore Connect than you should do so now.  There's a nice tutorial here: https://www.appcoda.com/in-app-purchases-guide/

 If you've already created your Products than grab your Product Ids by 

1. Logging into your AppStore Connect account.  
2. Going to 'My Apps' and then clicking on your app.
3. Then click on In-App Purchases
4. Click on each In-App purchase and grab it's Product Id on the right hand side
````

Next instantiate the pkIapHandler object, giving it your list of product Ids. 
```
// I would probably create an enum for your Product Ids
self.pkIapHandler = PKIAPHandler(productIds: ["your-product-id-1", "your-product-id-2", "your-product-id-3", "your-product-id-4"])
```

#### Making a Purchase

Making a purchase is simple.
First you need to get your products from the apple servers.  Use the following:
```
self.loadProducts { (products) in
  // self.products should be an array of SKProduct.  
  // Technically you don't have to store this value, but everytime you want to make a purchase you'll have to 
  // load the products again if you don't store these products somewhere, so it's up to you
  self.products = products 
}
```

Once you have the products, you can simple make a purchase using an Id.

```
self.purchaseProductWithId(id: "your-product-id") { (success) in
    if success {
        // Handle success!!!
    } else {
        // Handle failure
    }
}
```

And that's it!  I mentioned in a comment above, but just to reiterate, you should probably store your product ids using an enum, that will keep your code a lot cleaner and less buggy.

## Stripe

> Stripe integration is fairly simple.  In order to use it though, you will need some server-side integration which is not discussed here. You'll also need to create a Firebase project with Firestore integration.  None of this is discussed here, but the processes are fairly straightforward, just do a Google search and you should find tutorials very easily.  Also you'll need to set up a Stripe account.

1. First you need to deploy the Stripe NodeJS server to Heroku.  You can clone it from the repository at https://github.com/adeiji/DephynedStripe.git
2. Then you need to deploy it to heroku.  You can view deployment instructions at: https://heroku.com
3. Once you've deployed, you will need to set the config vars on Heroku, you'll need the following config vars:

```
// These are from Firebase
PROJECT_ID
PRIVATE_KEY_ID
PRIVATE_KEY
CLIENT_EMAIL
CLIENT_ID,
AUTH_URI
TOKEN_URI
AUTH_PROVIDER_X509_CERT_URL
CLIENT_X509_CERT_URL
DATABASE_URL

// From Stripe
STRIPE_SECRET_KEY
STRIPE_PUBLISHABLE_KEY
```

> You can view how to set config vars on Heroku here: https://devcenter.heroku.com/articles/config-vars

Once your config vars are set, you can now integrate Stripe payments into your iOS app.

In order to do this you'll need to instantiate a StripeManager object.

```
let stripeManager = StripeManager()
```

Now using the StripeManager object you can get a payment intent using your recently deployed Stripe NodeJS server.  You'll notice that there's two parameters that you'll need when calling the getPaymentIntent function.

1. ***collection*** - This is the name of the collection in Firestore which contains a document with an amount, that amount is how much this specific item cost.  It should be in cents, so $5 would be amount:500.  ***Make sure that the document contains the key value pair amount: int.***

2. ***documentId*** - This is the id of the document that contains the amount in the key value format ***amount: int***. As mentioned above, the amount is in cents, so $5 would be ***amount: 500***

Now that you now what params you need, you can call the function...

```
stripeManager.getPaymentIntent(collection: "your-collection-name", documentId: "your-document-id)
  .subscribe(onNext:{ [weak self] success in
      guard let self = self else { return }
      DispatchQueue.main.sync {
          if success {
            // handle succes
          } else {
            // handle failure
          }
      }
  }).disposed(by:self.disposeBag)  
```

***The payment intent is saved, so you don't have to worry about that, just make sure that you use the same StripeManager object when handling payment.***

Now you'll need to integrate the ***STPPaymentCardTextField***.  You can do whatever you want visually with this.

```
let cardTextField = STPPaymentCardTextField()
```

The payment card text field will visually show everything that the user needs to see to submit payment.

Now you can initiate payment:
```
stripeManager.pay(cardParams: cardTextField.cardParams, authViewController: self) { [weak self] (success) in
    guard let self = self else { return }

    if success {
      // show payment succeeded
    } else {
      // show payment failed
    }
}
```

And that's all for simple Stripe integration.  Now if you want to integrate Apple Pay...

## Apple Pay

Integrating Apple Pay is pretty straight forward.  Make sure that you have enabled Apple Pay support on Stripe as well.  Also make sure that you implement the STPPaymentProtocol protocol.  

```
class YourViewController: STPPaymentProtocol
```

Now the only thing you need to do is implement this function below.

```
// Get the apple pay button
let applePayButton: PKPaymentButton = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .black)

// Set the payment secret to the payment secret of the stripeManager
self.paymentIntentClientSecret = stripeManager.paymentIntentClientSecret

// The merchant identifier needs to be set up on stripe.com
let paymentRequest = Stripe.paymentRequest(withMerchantIdentifier: "your-merchant-identifier", country: "US", currency: "USD")

// Check to see if you have enabled Apple pay support on Stripe
applePayButton.isEnabled = Stripe.deviceSupportsApplePay()

// Configure the line items on the payment request
paymentRequest.paymentSummaryItems = [
    PKPaymentSummaryItem(label: "your-payment-name, amount: NSDecimalNumber(integerLiteral: {{your-tour-price}})),
    
    // The final line should represent your company;
    // it'll be prepended with the word "Pay" (i.e. "Pay iHats, Inc $50")
    PKPaymentSummaryItem(label: "company-name", amount: NSDecimalNumber(integerLiteral: {{amount}})),
]

// The user presses the applePayButton.  I use closures for buttons but you may use targets.  It's the code inside the
// closure that's important
applePayButton.addTargetClosure { [weak self] (_) in
    guard let self = self else { return }
    
    // Present Apple Pay payment sheet
    if  Stripe.canSubmitPaymentRequest(paymentRequest),
        let paymentAuthorizationViewController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest) {
            paymentAuthorizationViewController.delegate = self
            self.present(paymentAuthorizationViewController, animated: true)
        } else {
          // handle error
       }
}
```

The last function that must be implemented is the one below.  It is called after the workflow is finished of paying using Apple Pay.  The paymentSucceeded value is set within the Stripe Payment protocol
```
public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
  // Dismiss payment authorization view controller
  self.dismiss(animated: true, completion: {
      if (self.paymentSucceeded) {
         // handle success
      } else {
         // handle error
      }
  })
}
```
