

import Foundation
import SwiftUI

private var getToken: String? {return UserDefaults.standard.object(forKey: token_pref) as? String}
private var tokenFromPref: String? = getToken
private var token: String? = ""
private var account = ""
private var session = ""
private var tokenRefreshAccess = true

private var token_pref: String { return "TOKEN"}
private var session_pref: String { return "SESSION_ID"}
private var account_pref: String {return "ACCOUNT"}

private var clientEmail = ""
private var clientPhone = ""
private var clientFirstName = ""
private var clientLastName = ""
private var clientExtrafields: [String:Any]? = nil
private var clientGroups: [String]? = nil


private var libraryInit = false
private var addContactRequest = false

private var userCat = ""

// функция setToken - используется для передачи значения токена в библиотеку.
// в параметры передаётся значение token в формате String?

public func setToken (newToken: String?) {
    
    token = newToken
    
    let status =   tokenChangeStatus()
    
    let observer = TokenChangeObserver (object: status)
    
    print(observer.token)
    
    status.token = newToken
    
    
    if  newToken != getToken {
        
        UserDefaults.standard.set(newToken, forKey: token_pref)
    }
}
 
// классы tokenChangeStatus и TokenChangeObserver - необходимы для наблюдения за изменением токена позволяю сделать быстрое обновление токена на сервере в случаи его изменения.

private class tokenChangeStatus: NSObject {
    
    @objc dynamic var token = tokenFromPref
     
}


private class TokenChangeObserver: NSObject {
    
    @objc var token: tokenChangeStatus
    var observation: NSKeyValueObservation?
    
    init(object: tokenChangeStatus) {
        self.token = object
        super.init()
        
        observation = observe(\.token.token, options: [.old, .new], changeHandler: { object, token in
            
            var getSessionID: String? { return UserDefaults.standard.object(forKey: session_pref) as? String }
            var getAccount: String? {return UserDefaults.standard.object(forKey: account_pref) as? String }
            
            
            if token.newValue != token.oldValue {
                
                if (tokenRefreshAccess) {
                    
                    refreshToken(token: (token.newValue ?? "") ?? "", sessionID: getSessionID ?? "", account: getAccount ?? "")
                }
            }
            
          })
       }
    }

// функция logOut требуется для очистки данных пользователя - значение текущих аккаунта, сессии, токена удаляются.

public func logOut () {
    
    print("logOut")
     
    UserDefaults.standard.removeObject(forKey: session_pref)
    UserDefaults.standard.removeObject(forKey: token_pref)
    UserDefaults.standard.removeObject(forKey: account_pref)
  
    
}

// функция предоставляет необходимые url адреса для связи с сервером.

private func getUrl (selectUrl: String) -> String {
    
    var url = ""
    
    let urlMap: [String: String] =  ["createSession":"https://\(userCat)ext.enkod.ru/sessions",
                                      "startSession":"https://\(userCat)ext.enkod.ru/sessions/start",
                                      "subscribePush":"https://\(userCat)ext.enkod.ru/mobile/subscribe",
                                      "clickPush":"https://\(userCat)ext.enkod.ru/mobile/click/",
                                      "refreshToken":"https://\(userCat)ext.enkod.ru/mobile/token",
                                      
                                      "cart":"https://\(userCat)ext.enkod.ru/mobile/product/cart",
                                      "favourite":"https://\(userCat)ext.enkod.ru/mobile/product/favourite",
                                      "pageOpen":"https://\(userCat)ext.enkod.ru/mobile/page/open",
                                      "productOpen":"https://\(userCat)ext.enkod.ru/mobile/product/open",
                                      "productBuy":"https://\(userCat)ext.enkod.ru/mobile/product/order",
                                      "subscribe":"https://\(userCat)ext.enkod.ru/subscribe",
                                      "addExtraFields":"https://\(userCat)ext.enkod.ru/addExtraFields",
                                      "getPerson":"https://\(userCat)ext.enkod.ru/getCartAndFavourite",
                                      "updateBySession":"https://\(userCat)ext.enkod.ru/updateBySession"]
    
    
    
   url = urlMap [selectUrl] ?? ""
    
   return url
    
}

// функция  EnkodConnect (_account: String?) - функция выполняющая активацию библиотеки.
// в качестве параметра принимает значение названия аккаунта пользователя в формате String?.
// должна активироваться всегда вместе с активацией приложения.

public func EnkodConnect (_account: String?) {
    
    
    if (_account != nil) {
        
        account = _account ?? ""
        
        UserDefaults.standard.set(account, forKey: account_pref)
        
    }
    
    tokenRefreshAccess = true
    
    var getSessionID: String? { return UserDefaults.standard.object(forKey: session_pref) as? String }
    var getAccount: String? {return UserDefaults.standard.object(forKey: account_pref) as? String }
    var getToken: String? { return UserDefaults.standard.object(forKey: token_pref) as? String }
    
    
    if getSessionID == nil {
        
        createSession(account: account)
        
    }
    
    else {
        
        startSession (account: getAccount ?? "", sessionID: getSessionID ?? "")
            
    }
}


// функция createSession - создает новую сессию для связи с сервером.
// в качестве параметра принимает значение названия аккаунта пользователя в формате String.


private func createSession (account: String) {
    
    let urlFromMap = getUrl(selectUrl:"createSession")
    
    guard let url = URL(string: urlFromMap) else { return }
    var urlRequest = URLRequest(url: url)
    urlRequest.addValue(account, forHTTPHeaderField: "X-Account")
    urlRequest.httpMethod = "POST"
    URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           
            let sessionID: String? = json["session_id"] as? String? {

           
                session = sessionID ?? ""

                UserDefaults.standard.set(session, forKey: session_pref)
                
                print ("createSession")
        
            DispatchQueue.main.async {
                
                startSession (account: account, sessionID: session)
                
            }
            
        } else if error != nil {
            
            DispatchQueue.main.async {
                
               print ("created_session_error")
            }
        }
    }.resume()
}

// функция startSession - выполняет старт сессии.
// в качестве параметров принимает значение названия аккаунта пользователя в формате String а также значение сессии в формате String.

private func startSession (account: String, sessionID: String) {
    
    let urlFromMap = getUrl(selectUrl:"startSession")
    
    guard let url = URL(string: urlFromMap) else { return }
    var urlRequest = URLRequest(url: url)
    urlRequest.addValue(account, forHTTPHeaderField: "X-Account")
    urlRequest.addValue(sessionID, forHTTPHeaderField: "X-Session-Id")
    urlRequest.httpMethod = "POST"
    URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
       
        
        if data != nil {
                 
                print ("startSession")
            
                subscribePush (account: account, sessionID: sessionID, token: getToken ?? "")
            

        } else if error != nil {
            
            DispatchQueue.main.async {
                
                print ("start_session_error")
                
            }
        }
    }.resume()
}


// функция refreshToken - позволяет обновить значение токена на сервере Enkod
// в качестве параметров принимает значение токена в формате String, значение сессии в формате String, значение названия аккаунта пользователя в формате String
// значение токена на сервере сменится на значение переданное в параметре token

private func refreshToken(token: String, sessionID: String, account: String) {
    
 let urlFromMap = getUrl(selectUrl:"refreshToken")
    
 guard let url = URL(string: urlFromMap) else { return }
 var urlRequest = URLRequest(url: url)
 urlRequest.httpMethod = "PUT"
 urlRequest.addValue(account, forHTTPHeaderField: "X-Account")
 urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
 urlRequest.addValue(sessionID, forHTTPHeaderField: "X-Session-Id")

 let json: [String: Any] = ["sessionId": sessionID, "token": token]
 let jsonData = try? JSONSerialization.data(withJSONObject: json)
 urlRequest.httpBody = jsonData

 URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
     if data != nil {
         
         print("refreshToken")
         
     } else if error != nil {
         print("error refreshToken")
     }
 }.resume()
}

// фукция subscribePush (создает пустые персоны при наличии канала связи), реализует возможность добавления мобильного токена к персоне.
// принимает в качестве параметров значение названия аккаунта пользователя в формате String, значение сессии в формате String, значение токена в формате String.

private func subscribePush (account: String, sessionID: String, token: String) {
    
    print("\(account), \(token), \(sessionID)")
    
    let urlFromMap = getUrl(selectUrl:"subscribePush")
    
    guard let url = URL(string: urlFromMap) else { return }
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.addValue(account, forHTTPHeaderField: "X-Account")
    urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
    urlRequest.addValue(sessionID, forHTTPHeaderField: "X-Session-Id")
    
    let json: [String: Any] = ["sessionId": sessionID, "token": token, "os": "ios"]
    
    let jsonData = try? JSONSerialization.data(withJSONObject: json)
    urlRequest.httpBody = jsonData
     
    
    URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
        if data != nil {
            
            
            DispatchQueue.main.async {
                
                print ("subscribePush")
  
                let status = LibInitStatus()
                let observer = LibInitObserver (object: status)
                print(observer.status)
                status.statusName = "init"
            }
            
        } else if error != nil {
            
            DispatchQueue.main.async {
                
                print ("subscribe_push_error")
                
            }
        }
        
    }.resume()
}

// функция addContact позволяет создать новую персону в список контактов или добавить любые данные к пустой персоне.

public func addContact (email: String = "", phone: String = "", firstName: String = "", lastName: String = "", extraFields: [String:Any]? = nil, groups: [String]? = nil) {

    clientEmail = email
    clientPhone = phone
    clientFirstName = firstName
    clientLastName = lastName
    clientExtrafields = extraFields
    clientGroups = groups
    
    var getSessionID: String? {return UserDefaults.standard.object(forKey: session_pref) as? String}
    var getAccount: String? {return UserDefaults.standard.object(forKey: account_pref) as? String }
    
   
    var contactParams: [String: Any] = ["":""]
    
    
    var user  = [String:Any]()
    var extrafields = [String:Any]()
    var groupsArray = [String]()
    
    
    
    if !email.isEmpty {
        
        user["email"] = email
        
    }
    
    if !phone.isEmpty {
        
        user["phone"] = phone
        
    }
    
    if !firstName.isEmpty {
        
        user["firstName"] = firstName
        
    }
    
    if !lastName.isEmpty {
        
        user["lastName"] = lastName
        
    }
    
    if extraFields != nil && extraFields?.keys.count != 0 {
        
        for (k, v) in extraFields! {
            
            extrafields[k] = v
            
        }
        
        contactParams["fields"]  = user
    }

    
    if !extrafields.isEmpty {
        
        contactParams ["extraFields"] = extrafields
        
    }
    
    
    if groups != nil {
        
        groupsArray = groups!
    }
    
    
    if !groupsArray.isEmpty {
        
        contactParams["groups"] = groupsArray
    
    }
    
            JSONSerialization.isValidJSONObject(contactParams)
      
            let json = try? JSONSerialization.data(withJSONObject: contactParams, options: [])
                      
    DispatchQueue.main.async {
        
        
        if (libraryInit) {
            
            if getAccount != nil && getSessionID != nil {
                
                guard let urlRequest = prepareRequest("POST", getUrl(selectUrl:"subscribe"), json, account: getAccount ?? "", session: getSessionID ?? "") else { return }
                
                print ("libraryInit")
                
                URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
                    if data != nil {
                        
                        DispatchQueue.main.async {
                            do {
                                print("addContact email: \(email), phone: \(phone)")
                            }
                        }
                        
                    } else if error != nil {
                        DispatchQueue.main.async {
                            
                            print("add_contact_error")
                            
                        }
                    }
                }.resume()
            }
        }
        
        else {
            
            print ("nolibraryInit")
            let status = AddContactRequestStatus()
            let observer = AddContactRequestObserver(object: status)
            print(observer.status)
            status.status = "request"
            
      }
   }
}


// функция prepareRequest требуется для создания запросов трекинга - позволяет избежать повторяющийся код в методах трекинга
// принимает параметры: method - "GET"/ "POST", url - url адрес на который нужно отправить запрос, body - данные json, account - названия аккаунта пользователя, session - значение сессии

private func prepareRequest(_ method: String, _ url: String, _ body: Data?, account: String, session: String) -> URLRequest?{
    
    let url = URL(string: url)
    var urlRequest = URLRequest(url:url!)
    urlRequest.httpMethod = method
    urlRequest.addValue(account, forHTTPHeaderField: "X-Account")
    urlRequest.addValue(session, forHTTPHeaderField: "X-Session-Id")
    urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
    urlRequest.httpBody = body
    return urlRequest
    
}

// структура Product - необходима для передачи на сервер событий трекинга таких как - addToFavourite, removeFromFavourite, addToCart, removeFromCart, productOpen.
// структура состоит из полей которые необходимы для описания продукта.

public struct Product {
    
     public init(id: String? = nil, categoryId: String? = nil, count: Int? = nil, price: String? = nil, picture: String? = nil, params: [String : Any]? = nil) {
         
        self.id = id
        self.categoryId = categoryId
        self.count = count
        self.price = price
        self.picture = picture
        self.params = params
    }
    
    public var id: String?
    public var categoryId: String?
    public var count: Int?
    public var price: String?
    public var picture: String?
    public var params: [String:Any]?
    
}


// функция TrackingMapBilder возвращает значение в виде словаря [String:Any] который используется для запросов трекинга использующих структуру Product. Позволяет снизить количество повторяющегося кода.
// в качестве параметра принимает структуру Product

public func TrackingMapBilder(_ product: Product) -> [String:Any] {
    var productMap = [String:Any]()
    
  
    if product.id != nil {
        productMap["productId"] = product.id
    }
    
    if product.categoryId != nil {
        productMap["categoryId"] = product.categoryId
    }
    
    if product.count != nil {
        productMap["count"] = product.count
    }
    
    if product.price != nil {
        productMap["price"] = product.price
    }
    
    if product.picture != nil {
        productMap["picture"] = product.picture
    }
    
    if product.params != nil && product.params?.keys.count != 0 {
    
        for (key, _) in product.params! {
            
            productMap[key] = product.params?[key]
            
        }
    }

    return productMap
}


// функция addToFavourite позволяет передать на сервер информацию о добавлении товара в список избранного - событие productLike
// в качестве параметра принимает структуру Product

public func addToFavourite (product: Product) {
    
    var getSessionID: String? {return UserDefaults.standard.object(forKey: session_pref) as? String}
    var getAccount: String? {return UserDefaults.standard.object(forKey: account_pref) as? String }
    
    if getSessionID != nil && getAccount != nil  {
        
    var map = TrackingMapBilder(product)
    
    map ["action"] = "productLike"
    
    let lastUpdate = Int(Date().timeIntervalSince1970)
    
    let wishlist: [String:Any] = ["products":map["productId"] ?? "", "lastUpdate": lastUpdate]

    let history: [[String:Any]] = [map]
    
    let json: [String : Any] = ["wishlist": wishlist, "history": history]
    
    do {
        
        guard JSONSerialization.isValidJSONObject(json) else {
            throw TrackerErr.invalidJson
            
        }
        
        let requestBody = try JSONSerialization.data(withJSONObject: json)
        
            
        guard let urlRequest = prepareRequest("POST", getUrl(selectUrl:"favourite"), requestBody, account: getAccount ?? "", session: getSessionID ?? "") else { return }
            
            
            URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
                
                if data != nil {
                    
                    
                    DispatchQueue.main.async {
                        print("AddToFavourite")
                    }
                    
                } else if error != nil {
                    
                    DispatchQueue.main.async {
                        
                        print("Error AddToFavourite")
                    }
                }
                
            }.resume()
            
        } catch {
            
            print("Error AddToFavourite")
        }
    }
}

// функция removeFromFavourite позволяет передать на сервер информацию о исключении товара из списка избранного - событие productDislike
// в качестве параметра принимает структуру Product


public func removeFromFavourite (product: Product) {
    
    
    var getSessionID: String? {return UserDefaults.standard.object(forKey: session_pref) as? String}
    var getAccount: String? {return UserDefaults.standard.object(forKey: account_pref) as? String }
    
    if getSessionID != nil && getAccount != nil  {
        
        var map = TrackingMapBilder(product)
        
        
        map ["action"] = "productDislike"
        
        let lastUpdate = Int(Date().timeIntervalSince1970)
        
        let wishlist: [String:Any] = ["products":map["productId"] ?? "", "lastUpdate": lastUpdate]
        
        let history: [[String:Any]] = [map]
        
        let json: [String : Any] = ["wishlist": wishlist, "history": history]
        
        
        do {
            
            guard JSONSerialization.isValidJSONObject(json) else {
                throw TrackerErr.invalidJson
            }
            let requestBody =  try JSONSerialization.data(withJSONObject: json)
            
            
            guard let urlRequest = prepareRequest("POST", getUrl(selectUrl:"favourite"), requestBody, account: getAccount ?? "", session: getSessionID ?? "") else { return }
            
            URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
                if data != nil {
                    
                    
                    DispatchQueue.main.async {
                        
                        print("RemoveFromFavourite")
                    }
                } else if error != nil {
                    
                    DispatchQueue.main.async {
                        
                        print("Error RemoveFromFavourite")
                    }
                }
            }.resume()
            
        } catch {
            
            print("Error RemoveFromFavourite")
        }
    }
}


// функция addToCart позволяет передать на сервер информацию о добавлении товара в корзину - событие productAdd
// в качестве параметра принимает структуру Product

public func addToCart (product: Product) {
    
    
    print ("dispatch")
    
    var getSessionID: String? {return UserDefaults.standard.object(forKey: session_pref) as? String}
    var getAccount: String? {return UserDefaults.standard.object(forKey: account_pref) as? String }
    
    
    if getSessionID != nil && getAccount != nil  {
        
        var map = TrackingMapBilder(product)
        
        map ["action"] = "productAdd"
        
        let lastUpdate = Int(Date().timeIntervalSince1970)
        
        let cart: [String:Any] = ["lastUpdate": lastUpdate, "products": [["productId": map["productId"]]]]
        
        let history: [[String:Any]] = [map]
        
        let json: [String : Any] = ["cart": cart, "history": history]
        
        do {
            
            guard JSONSerialization.isValidJSONObject(json) else {
                throw TrackerErr.invalidJson
            }
            
            let requestBody =  try JSONSerialization.data(withJSONObject: json)
            
            guard let urlRequest = prepareRequest("POST", getUrl(selectUrl:"cart"), requestBody,  account: getAccount ?? "", session: getSessionID ?? "") else { return }
            
            URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
                if data != nil {
                    
                    
                    DispatchQueue.main.async {
                        
                        print("AddToCart")
                    }
                } else if error != nil {
                    DispatchQueue.main.async {
                        
                        print("Error AddToCart")
                    }
                }
            }.resume()
        } catch {
            
            print("Error AddToCart")
        }
    }
}


// функция removeFromCart позволяет передать на сервер информацию об исключении товара из корзины - событие productRemove
// в качестве параметра принимает структуру Product

public func removeFromCart (product: Product) {
    
    var getSessionID: String? {return UserDefaults.standard.object(forKey: session_pref) as? String}
    var getAccount: String? {return UserDefaults.standard.object(forKey: account_pref) as? String }
    
    if getSessionID != nil && getAccount != nil  {
        
        var map = TrackingMapBilder(product)
        
        map ["action"] = "productRemove"
        
        let lastUpdate = Int(Date().timeIntervalSince1970)
        
        let cart: [String:Any] = ["lastUpdate": lastUpdate, "products": [["productId": map["productId"]]]]
        
        let history: [[String:Any]] = [map]
        
        let json: [String : Any] = ["cart": cart, "history": history]
        
        
        do {
            
            guard JSONSerialization.isValidJSONObject(json) else {
                throw TrackerErr.invalidJson
                
            }
            
            let requestBody = try JSONSerialization.data(withJSONObject: json)
            
            
            guard let urlRequest = prepareRequest("POST", getUrl(selectUrl:"cart"), requestBody, account: getAccount ?? "", session: getSessionID ?? "") else { return }
            
            URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
                if data != nil {
                    
                    DispatchQueue.main.async {
                        
                        print("RemoveFromCart")
                        
                    }
                } else if error != nil {
                    DispatchQueue.main.async {
                        
                        print("Error RemoveFromCart")
                        
                    }
                }
            }.resume()
            
        } catch {
            
            print("Error RemoveFromCart")
            
        }
    }
}

// функция productOpen позволяет передать на сервер информацию об открытии карточки товара - событие productOpen
// в качестве параметра принимает структуру Product

public func productOpen (product: Product) {
    
    var getSessionID: String? {return UserDefaults.standard.object(forKey: session_pref) as? String}
    var getAccount: String? {return UserDefaults.standard.object(forKey: account_pref) as? String }
    
    if getSessionID != nil && getAccount != nil  {
        
        let map = TrackingMapBilder(product)
        
        let lastUpdate = Int(Date().timeIntervalSince1970)
 
        
        let product = ["id": map["productId"] ?? "", "lastUpdate": lastUpdate, "params" : map]
        
       
        
        let json: [String : Any] = ["action": "productOpen","product": product]
        
        
        do {
            
            let requestBody =   try JSONSerialization.data(withJSONObject: json)
            guard let urlRequest = prepareRequest("POST", getUrl(selectUrl:"productOpen"), requestBody,  account: getAccount ?? "", session: getSessionID ?? "") else { return }
            
            
            
            URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
                if data != nil {
                    
                    
                    DispatchQueue.main.async {
                        
                        print("ProductOpen")
                        
                    }
                } else if error != nil {
                    DispatchQueue.main.async {
                        
                        print("Error ProductOpen")
                    }
                }
            }.resume()
            
        } catch {
            
            print("Error ProductOpen")
            
        }
    }
}

// структура Order необходима для передачи на сервер события покупки
// структура состоит из полей которые необходимы для описания ордера.

public struct Order {
    
    public init(id: String? = nil, count: Int? = nil, price: String? = nil, params: [String : Any]? = nil) {
        
        self.id = id
        self.count = count
        self.price = price
        self.params = params
    }
    
    public var id: String?
    public var count: Int?
    public var price: String?
    public var params: [String:Any]?
   
}

// функция productBuy необходима для передачи данных о покупке. Для проведения операции покупки необходимо передать массив структур Order.
// Также можно передать дополнительные параметры:
// orderId - номер заказа,
// orderParams - словарь необходимый для передачи дополнительной информации о заказе,
// orderDatetime - информация о дате и времени заказа

public func productBuy (orders: [Order], orderId: String? = nil, orderParams: [String:Any]? = nil, orderDatetime: String? = nil) {
    
    var getSessionID: String? {return UserDefaults.standard.object(forKey: session_pref) as? String}
    var getAccount: String? {return UserDefaults.standard.object(forKey: account_pref) as? String }
    
    if getSessionID != nil && getAccount != nil  {
        
        var orderId = orderId
        var sum = 0.0
        var orderInfo = [String:Any]()
        var orderFields = [String:Any]()
        var orderList = [[String:Any]]()
        var dopParams = [String:Any]()
        

        
        func sumCalculation (price: Double, count: Double) throws {
            sum += price*count
        }
        
        if (orders.count != 0) {
            
            for i in 0 ... orders.count - 1 {
                
                if (orders[i].id != nil && orders[i].id != "" &&
                    orders[i].price != nil && orders[i].price != "" &&
                    orders[i].count != nil && orders[i].count ?? 1 > 0
                    
                ) {
                    
                    orderFields["productId"] = orders[i].id
                    orderFields["price"] = orders[i].price
                    orderFields["count"] = orders[i].count
                    
                    if orders[i].params != nil && orders[i].params?.keys.count != 0 {
                        
                        
                        for (k, v) in orders[i].params! {
                            orderFields[k] = v
                        }
                    }
                    
                    
                    do {
                        try sumCalculation(price: Double(orders[i].price ?? "0.0") ?? 0.0, count: Double(orders[i].count ?? 0))
                    }catch {
                        
                    }
                    
                    orderList.append(orderFields)
                    
                    
                }
            }
        }
        
        
        if orderId == "" || orderId == nil {orderId = UUID().uuidString.lowercased() }
        
        let orderSum = String(format: "%.2f", sum)
        
        if orderParams != nil && orderParams?.keys.count != 0 {
            
            for (k, v) in orderParams! {
                
                dopParams[k] = v
            }
        }
        
        
        dopParams["sum"] = orderSum
        
        if orderDatetime != nil {
            dopParams["orderDatetime"] = orderDatetime
        }
        
        
        orderInfo["items"] = orderList
        orderInfo["order"] = dopParams
        
        
        let json = ["orderId": orderId as Any,
                    "orderInfo": orderInfo] as [String : Any]
        
        do {
            
            guard JSONSerialization.isValidJSONObject(json) else {
                throw TrackerErr.invalidJson
                
            }
            
            let requestBody =  try JSONSerialization.data(withJSONObject: json)
            
            
            guard let urlRequest = prepareRequest("POST", getUrl(selectUrl:"productBuy"), requestBody,  account: getAccount ?? "", session: getSessionID ?? "") else { return }
            
            URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
                if data != nil {
                    DispatchQueue.main.async {
                        
                        print("productBuy")
                    }
                } else if error != nil {
                    DispatchQueue.main.async {
                        
                        print("Error productBuy")
                    }
                }
            }.resume()
            
        } catch {
            
            print("Error productBuy")
        }
    }
}

// функция clickPush - данный метод предназначен для передачи данных на сервер о том, что было совершено нажатие на push уведомление, c информацией о том, какие действия были установлены для данного уведомления.


 public func clickPush (pd: [String:Any]){
     
    let urlFromMap = getUrl(selectUrl:"clickPush")
    
    var getSessionID: String? {return UserDefaults.standard.object(forKey: session_pref) as? String}
    var getAccount: String? {return UserDefaults.standard.object(forKey: account_pref) as? String }
     
      
     
    guard let url = URL(string: urlFromMap) else { return }
     
     if getAccount != nil && getSessionID != nil {
         
         
         
         let account = getAccount ?? ""
         let session = getSessionID ?? ""
    
         var urlRequest = URLRequest(url: url)
         urlRequest.addValue(account, forHTTPHeaderField: "X-Account")
         
         urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
         urlRequest.httpMethod = "POST"
         
         let data = pd
         
         let json: [String: Any] = ["sessionId": session, "personId": Int(data["personId"] as! String) ?? 0, "messageId": Int(data["messageId"] as! String) ?? -1, "intent": Int(data["intent"] as! String) ?? 2, "url": data["url"]as! String]
         
       
         
         let jsonData = try? JSONSerialization.data(withJSONObject: json)
         urlRequest.httpBody = jsonData
         URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
             
             if data != nil {
                 
                 print("clickPush")
                 
             } else if error != nil {
                 
                 print("Error clickPush")
             }
         }.resume()
     }
}


// функция pushClickAction предназначена для обработки события нажатия на push уведомления
// активацию данного функции следует производить в функции userNotificationCenter класса AppDelegate
// в качестве параметров принимает - userInfo - данные полученные и пуш уведомления, Identifier - идентификатор кнопки push уведомления.
// Identifier можно получить вызвав response.actionIdentifier в методе:
// public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void)
   

public func pushClickAction (userInfo: [AnyHashable : Any], Identifier: String) -> String {
    
    
    let intent_0 = (userInfo[AnyHashable("intent_0")] as? String)
    let intent_1 = (userInfo[AnyHashable("intent_1")] as? String)
    let intent_2 = (userInfo[AnyHashable("intent_2")] as? String)
    let intent_3 = (userInfo[AnyHashable("intent_3")] as? String)
  
    let url_0 = (userInfo[AnyHashable("url")] as? String)
    let url_1 = (userInfo[AnyHashable("url_1")] as? String)
    let url_2 = (userInfo[AnyHashable("url_2")] as? String)
    let url_3 = (userInfo[AnyHashable("url_3")] as? String)
    
    var deepLink = ""
    
    switch Identifier {
        
    case "com.apple.UNNotificationDefaultActionIdentifier":
        
        if url_0 != nil && intent_0 != nil {
            
            if intent_0 == "0" {
                
                deepLink = url_0 ?? "nil"
                
            }else {deepLink = "nil"}
            
        }else {deepLink = "nil"}
        
    case "button1":
     
        if url_1 != nil && intent_1 != nil {
            
            if intent_1 == "0" {
                
                deepLink = url_1 ?? "nil"
                
            }else {deepLink = "nil"}
            
        }else {deepLink = "nil"}
        
    case "button2":
     
        if url_2 != nil && intent_2 != nil {
            
            if intent_2 == "0" {
                
                deepLink = url_2 ?? "nil"
                
            }else {deepLink = "nil"}
            
        }else {deepLink = "nil"}
        
    case "button3":
     
        if url_3 != nil && intent_3 != nil {
            
            if intent_3 == "0" {
                
                deepLink = url_3 ?? "nil"
                
            }else {deepLink = "nil"}
            
        }else {deepLink = "nil"}

    default:
        
      deepLink = "nil"

    }


    func intentAction (Identifier: String) {
        
        if Identifier == "com.apple.UNNotificationDefaultActionIdentifier" {
             
            var dataForPushClick = [String: Any]()
            
            dataForPushClick = [
              
              "personId": userInfo[AnyHashable("personId")] ?? "0",
              "messageId": userInfo[AnyHashable("messageId")] ?? "0",
              "intent": intent_0 ?? "",
              "url": url_0 ?? ""
              
            ]
            
            clickPush (pd: dataForPushClick)
                              
            switch intent_0 {
                
            case "0":
                
                print("deeplink open")
                
            case "1":
              
                do {
                    if let url = URL(string: url_0 ?? ""), UIApplication.shared.canOpenURL(url) {
                        
                        UIApplication.shared.open(url)
                    }
                }
                 
            default:
                
                print("openApp")
   
            }
        }
        
        if Identifier == "button1" {
            
            var dataForPushClick = [String: Any]()
            
            dataForPushClick = [
              
              "personId": userInfo[AnyHashable("personId")] ?? "0",
              "messageId": userInfo[AnyHashable("messageId")] ?? "0",
              "intent": intent_1 ?? "",
              "url": url_1 ?? ""
              
            ]
            
            
            
            clickPush (pd: dataForPushClick)
         
            switch intent_1 {
                
            case "0":
                
                print("deeplink open")
                
            case "1":
                
                do {
                
                    
                    if let url = URL(string: url_1 ?? ""), UIApplication.shared.canOpenURL(url) {
                        
                       UIApplication.shared.open(url)
                        
                    }
                     
                }
                
            default:
                print("openApp")
                
            }
        }
        if Identifier == "button2" {
            
            var dataForPushClick = [String: Any]()
            
            dataForPushClick = [
              
              "personId": userInfo[AnyHashable("personId")] ?? "0",
              "messageId": userInfo[AnyHashable("messageId")] ?? "0",
              "intent": intent_2 ?? "",
              "url": url_2 ?? ""
              
            ]
            
            clickPush (pd: dataForPushClick)
         
            switch intent_2 {
            case "0":
                
                print("deeplink open")
                
            case "1":
                do {
                    if let url = URL(string: url_2 ?? ""), UIApplication.shared.canOpenURL(url) {
                        
                        UIApplication.shared.open(url)
                    }
                }
            default:
                print("openApp")
                
            }
        }
        
        if Identifier == "button3" {
            
            var dataForPushClick = [String: Any]()
            
            dataForPushClick = [
              
              "personId": userInfo[AnyHashable("personId")] ?? "0",
              "messageId": userInfo[AnyHashable("messageId")] ?? "0",
              "intent": intent_3 ?? "",
              "url": url_3 ?? ""
              
            ]
            
            clickPush (pd: dataForPushClick)
         
            switch intent_3 {
                
            case "0":
                
                print("deeplink open")
                
            case "1":
                do {
                    if let url = URL(string: url_3 ?? ""), UIApplication.shared.canOpenURL(url) {
                        
                        UIApplication.shared.open(url)
                    }
                }
            default:
                print("openApp")
                
            }
        }
    }
    
   intentAction (Identifier: Identifier)
    
    return deepLink
    
}

// методы devSwitch () / prodSwitch () предназначены для переключения между серверами

public func devSwitch () {
    
    userCat = "dev."
    
}

public func prodSwitch () {
    
    userCat = ""
    
}


// классы LibInitStatus и LibInitObserver - создают наблюдатель который меняет свое значение в момент активации библиотеки - которая полность завершается после положительного ответа метода subscribePush
// предназначен для контроля работы метода addContact который ожидает завершения процесса активации

class LibInitStatus: NSObject {
    
    @objc dynamic var statusName = "no_init"
     
}

class LibInitObserver: NSObject {
            @objc var status: LibInitStatus
    var observation: NSKeyValueObservation?
    
    init(object: LibInitStatus) {
        self.status = object
        super.init()
        
        observation = observe(\.status.statusName, options: [.old, .new], changeHandler: { object, change in
            
        
            
            libraryInit = true
            
            if (addContactRequest) {
                
                
                addContact(email: clientEmail, phone: clientPhone, firstName: clientFirstName, lastName: clientLastName, extraFields: clientExtrafields, groups: clientGroups)
                
            
                }
            })
        }
    }


// классы AddContactRequestStatus  и AddContactRequestObserver - создают наблюдатель который меняет свое значение в момент активации метода addContact сообщая о том, что есть запрос на добавление нового контакта
// взаимодействие наблюдателей активации библиотеки и запроса на добавление контакта - дает возможность одновременной активации методов EnkodConnect и AddContact

class AddContactRequestStatus: NSObject {
    
    @objc dynamic var status = "no_request"
     
}


class AddContactRequestObserver: NSObject {
            @objc var status: AddContactRequestStatus
    var observation: NSKeyValueObservation?
    
    init(object: AddContactRequestStatus) {
        self.status = object
        super.init()
        
        observation = observe(\.status.status, options: [.old, .new], changeHandler: { object, change in
            
            addContactRequest = true
            
            
            })
        }
    }


// класс перечисления TrackerErr предназначен для фиксации исключений

enum TrackerErr : Error{
    case emptyProductId
    case notExistedProductId
    case emptyCart
    case emptyFavourite
    case emptyEmail
    case emptyEmailAndPhone
    case invalidJson
    case badRequest
    case emptyProducts
    case alreadyLoggedIn
    case emptySession
}


