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
