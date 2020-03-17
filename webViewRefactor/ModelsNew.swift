//
//  ModelsNew.swift
//  swiftRedux
//
//  Created by Blake  on 2020-03-14.
//  Copyright © 2020 b. All rights reserved.
//
import SwiftUI
import UIKit
import Foundation

//newJson
let jsonCartStr = """
{"products":[{"id":0,"name":"A bunch of random flowers","price":30.550000000000001,"description":"Hand picked bouqet?"}],"cartTotal":61.100000000000001,"merchantEmail":"myshop@flowers.ca","sessionId":"0x1","merchantName":"My Best Flower Shop","cartProducts":[{"quantity":2,"id":0,"name":"A bunch of random flowers","price":30.550000000000001,"description":"Hand picked boq?"}],"merchantSite":"flowers.ca"}
"""
// MARK: - Key Models
// note: use var + optional when might not initialize with a value. examples: sessionId, product quantity.
struct Cart: Codable {
    var merchantName: String = "Merchant" //default val
    let merchantSite: String
    let merchantEmail: String
    let products: [Product]
    var sessionId: String?
    let cartProducts: [Product]
    let cartTotal: Double
    var previousCartTotal: Double?

    enum CodingKeys: String, CodingKey {
        case merchantName, merchantSite, merchantEmail, products
        case sessionId
        case cartProducts, cartTotal, previousCartTotal
    }
}
// MARK: - Product
struct Product: Codable, Hashable, Identifiable {
    let name: String
    let description: String?
    let price: Double
    var id: Int = 0
    var quantity: Int?
 

    enum CodingKeys: String, CodingKey {
        case name, price
        case description
        case id
        case quantity
    }
}


struct MHelpers {
//guard against failed conversion to Data type
static func getSampleJsonCart() -> String {
    return jsonCartStr
}

//MARK: Important cart creation function. remove the default param for publication.
static func jsonDecodeToCart(jsonStr: String = jsonCartStr) -> Cart? {
    print(jsonStr)
    guard let jsonStrData: Data = jsonStr.data(using: .utf8) else {
        print("error converting json to Data type")
        return nil
    }
    let cartObject: Cart = try! JSONDecoder().decode(Cart.self, from: jsonStrData)
    return cartObject
    
}


//MARK: Struct samples:
static var productSamp: [Product] = [Product(name: "A bunch of random flowers",  description: "Hand picked bouqet?", price: 30.55, id: 0)]
static var cartProductSamp: [Product] = [Product(name: "A bunch of random flowers", description: "Hand picked boq?", price: 30.55, id: 0, quantity: 2)]
static var cartSamp: Cart = Cart(merchantName: "My Best Flower Shop", merchantSite: "flowers.ca", merchantEmail: "myshop@flowers.ca", products: productSamp, sessionId: "0x1", cartProducts: cartProductSamp, cartTotal: getCartTotal(cart: cartProductSamp), previousCartTotal: 12.31)

static func getCartSample() -> Cart {
    return cartSamp
}
    
    

//MARK: Sample encoding of cart:
static func cartToJson(cart: Cart?) -> String {
    let jsonEncoder = JSONEncoder()
    //jsonEncoder.outputFormatting = .prettyPrinted //- why does this produce erroring string of json when attempting to turn back into cart struct?
    
    let jsonData = try! jsonEncoder.encode(cart ?? MHelpers.cartSamp)
    let jsonCart: String = String(data: jsonData, encoding: String.Encoding.utf8)!
    print(jsonCart)
    print(jsonCart.count)
    return jsonCart
}
    
    static func cartToJsonCartProducts(cart: Cart) -> String {
        var jsonCartProducts: String = " "
        
        let jsonEncoder = JSONEncoder()
        for cp in cart.cartProducts {
            let jsonData = try! jsonEncoder.encode(cp)
            let jsonCp: String = String(data: jsonData, encoding: String.Encoding.utf8)!
            if jsonCp != nil || jsonCp != "" {
                jsonCartProducts += jsonCp
            }
        }

        return jsonCartProducts
        
    }
    static func cartProdString(cart: Cart) -> String {
            var jsonCartProducts: String = ""
            

           // let jsonEncoder = JSONEncoder()
            for cp in cart.cartProducts {
                 if cp != nil {
                    var name = cp.name
                    var q = cp.quantity
                    
                    jsonCartProducts += "product: " + String(describing: name)
                    jsonCartProducts += " - quantity: "
                    jsonCartProducts += String(describing: cp.quantity!)
                    jsonCartProducts +=  " \\n " //newline after a product.
                }
            }
            
            jsonCartProducts += "\\nTotal: $" + String(cart.cartTotal)
                
//                let jsonData = try! jsonEncoder.encode(cp)
//                let jsonCp: String = String(data: jsonData, encoding: String.Encoding.utf8)!
//                if jsonCp != nil || jsonCp != "" {
//                    jsonCartProducts += jsonCp
//                }
//            }
            
    //        let jsonData = try! jsonEncoder.encode(cart.cartProducts ?? MHelpers.cartProductSamp)
    //        let jsonCartProducts: String = String(data: jsonData, encoding: String.Encoding.utf8)!
    //        print(jsonCartProducts)
            return jsonCartProducts
            
        }
}


//guard against failed conversion to Data type

//MARK: for peers:
struct QrPeer: Codable, Identifiable {
    let id = UUID() //case using in foreach type scenerio
    let name: String
    let email: String
    let amount: Double
}


//MARK: Model helpers
//1) convert qr scan json to cart struct.
//2) calculate cart total in app to be sure.
//3) get JsonCart string - this simulates a qr scan.
//4) may need helpers to:
//a) verify cart against direct app-obtained merchant info. (how to best obtain merchant store info from html?)
//b) set cart up for view rendering.
//c)

//todo: call this once with cart data. call this once with direct app obtained merchant data. compare.
func getCartTotal(cart: [Product]) -> Double {
    let total = cart.reduce(0.00, { result, item in
        let itemTotal = item.price * Double(item.quantity ?? 0) //0 if quantity not set.
        return result + itemTotal
    })
    print("total:", total)
    return total.roundAndTruncate(digits: 2)
}

func getJSONString(cart: [Product]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    do {0
        let jsonData = try JSONEncoder().encode(cart)
        let jsonString = String(data: jsonData, encoding: .utf8)
        return jsonString ?? ""
    } catch {
       return ""
    }
}

//Double type - Currency-ification

//for views
extension Double {
    func roundToString(digits: Int) -> String {
        let divisor = pow(10.0, Double(digits))
        let rounded = (self * divisor).rounded() / divisor
        let truncated = Double(floor(pow(10.0, Double(digits)) * self)/pow(10.0, Double(digits))) //this truncation doesn't seem to actually work.
        
        return String(format: "%.2f", truncated)
    }
}

//for models
extension Double {
    func roundAndTruncate(digits: Int) -> Double {
        let divisor = pow(10.0, Double(digits))
        let rounded = (self * divisor).rounded() / divisor
        let truncated = Double(floor(pow(10.0, Double(digits)) * self)/pow(10.0, Double(digits)))
        return truncated
    }
}
