# Инструкция по подключению enkodio-ios-sdk

Перед добавлением и использованием библиотеки enkodio:iossdk рекомендуем ознакомиться:

- с [README Firebase Cloud Messaging](<README Firebase Cloud Messaging.md>)

 ## Инициализация библиотеки и добавление контакта

1. Добавьте зависимость enkod-ios-sdk в pod файл вашего проекта:  ` pod "enkod-ios-sdk", :git => 'https://github.com/enkodio/enkod-ios-sdk.git' ` 
  
2. Импортируйте зависимость  enkod-ios-sdk в необходимые классы и представления командой import: enkodio-ios-sdk

3. Выполните функцию EnkodConnect(account: String:  «account»), где «account» - имя клиента Enkod (при первой инициализации библиотеки, с использованием Firebase Cloud Messaging, данный метод следует активировать после получения токена, иначе токен контакта передастся на сервер только после перезагрузки приложения). 

4. Для регистрации контакта воспользуйтесь методом
```swift
 addContact(

           email: String = "",
           phone: String = "" , 
           firstName: String = "",
           lastName:  String = "",
           extraFields: [String: Any]? = nil,
           groups: [Sring]? = nil
) 
```
- регистрацию контакта можно произвести указав **email** и/или **phone**.
- опционально: параметры firstName и lastName - предназначены для указания имени и фамилии
- опционально: для указания дополнительной информации контакта можно передать в качестве параметра `"extraFields"` словарь `[String: Any]?` содержащий необходимые ключи и значения.
- опционально: параметр groups позволяет прикрепить контакт к необходимым группам рассылок. Для этого необходимо передать [String]? состоящий из системных имен групп рассылок.

5. Опционально - подключение push уведомлений

- добавьте Firebase cloud messaging в проект

- в таргет приложения в разделе  Signing & Capabilities добавьте разрешение  Push Notification

- добавьте следующие функции  в класс AppDelegate, а также расширения для данного класса:

 ```swift
public class AppDelegate: NSObject, UIApplicationDelegate {
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
          
            FirebaseApp.configure()

            Messaging.messaging().delegate = self

        if #available(iOS 10.0, *) {
            
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { _, _ in }
            )

            application.registerForRemoteNotifications()
    
            }
        
            return true
    
    }

    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
            Messaging.messaging().apnsToken = deviceToken
         
        print("to register: \(deviceToken)")
        
    }
 
    public func application(_ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        
         
        print("Failed to register: \(error)")
        
       }
    }


extension AppDelegate: MessagingDelegate {
    
    public func messaging( _ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?)
    
    {
       
        Messaging.messaging().token { token, err in
            
            if let token = token {
                
                
                setToken(newToken: token)
   
            }
            if err != nil {
                
                print("error in receiving token: \(String(describing: err))")
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate{
      
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
    completionHandler([.alert, .sound])
      
  }
 
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {


        let userInfo = response.notification.request.content.userInfo
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        
            let deepLink = pushClickAction (userInfo: userInfo, Identifier: response.actionIdentifier)  
        }
        
     completionHandler()
      
  }
}

 ```

 Где функция setToken(newToken: token) - передает token fcm в библиотеку,  функция  pushClickAction (userInfo: userInfo, Identifier: response.actionIdentifier) - обрабатывает нажатие на уведомления.

 - Добавьте зависимости Firebase Cloud Messaging в проект

   выполните загрузку пакета Firebase с git: > https://github.com/firebase/firebase-ios-sdk
   выполните импорт в проекте: 

   ```swift
   import Firebase
   import FirebaseCore
   import FirebaseMessaging
   ```
 
 -	При использовании Swift Ui добавьте  адаптер для класса AppDelegate: ` @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate `

 -  Создайте новый таргет Notification Service Extension 

 -	Замените весь код в созданном классе на следующий:


 ```swift
import UserNotifications

import UIKit

 public class NotificationService: UNNotificationServiceExtension {

  private var contentHandler: ((UNNotificationContent) -> Void)?

  private var bestAttemptContent: UNMutableNotificationContent?

  public override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {


  let text_1 = (request.content.userInfo[AnyHashable("text_1")] as? String)

  let text_2 = (request.content.userInfo[AnyHashable("text_2")] as? String)

  let text_3 = (request.content.userInfo[AnyHashable("text_3")] as? String)

  var actions = [UNNotificationAction(identifier: "",  title: "", options: [])]

  if text_1 != nil && text_1 != ""  {

  actions.removeAll()

  actions.append(UNNotificationAction(identifier: "button1",  title: text_1 ?? "", options: []))

  }else {actions.removeAll()}

  if text_2 != nil && text_2 != ""   {

  actions.append(UNNotificationAction(identifier: "button2",  title: text_2 ?? "", options: []))

 }

 if text_3 != nil && text_3 != ""    {

  actions.append(UNNotificationAction(identifier: "button3",  title: text_3 ?? "", options: []))

 }


  let simpleCategory = UNNotificationCategory(identifier: "cat1", actions: actions, intentIdentifiers: [], options: [])

  UNUserNotificationCenter.current().setNotificationCategories([simpleCategory])


  self.contentHandler = contentHandler

  bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

  defer {

  contentHandler(bestAttemptContent ?? request.content)

 }

  bestAttemptContent?.categoryIdentifier = "cat1"

  guard let attachment = request.attachment else { return }
 
  bestAttemptContent?.attachments = [attachment]

 }

  public override func serviceExtensionTimeWillExpire() {

  if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {

  contentHandler(bestAttemptContent)

    }
  }
}


 extension UNNotificationRequest {

  var attachment: UNNotificationAttachment? {

  let image = content.userInfo[AnyHashable("image")] as? String

  guard let attachmentURL = image, let imageData = try? Data(contentsOf: URL(string: attachmentURL)!)

 else {

  return nil

 }

 return try? UNNotificationAttachment(data: imageData, options: nil)

  }
}

 extension UNNotificationAttachment {

  convenience init(data: Data, options: [NSObject: AnyObject]?) throws {


  let fileManager = FileManager.default

  let temporaryFolderName = ProcessInfo.processInfo.globallyUniqueString

  let temporaryFolderURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(temporaryFolderName, isDirectory: true)

  try fileManager.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true, attributes: nil)

  let imageFileIdentifier = UUID().uuidString + ".jpg"

  let fileURL = temporaryFolderURL.appendingPathComponent(imageFileIdentifier)

  try data.write(to: fileURL)

  try self.init(identifier: imageFileIdentifier, url: fileURL, options: options)

  }
}

```

 Приложение готово к получению push уведомлений

 
 ## Tracking


Библиотека  enkodio:iossdk содержит следующие функции трекинга:

- `addToCart(product: Product)`

передает на сервер информацию о добавления товара в корзину (событие "productAdd")

- `removeFromCart(product: Product)`

передает на сервер информацию об исключении товара из корзины (событие "productRemove")

- `addToFavourite(product: Product)`

передает на сервер информацию о добавления товара в избранное (событие "productLike")

- `removeFromFavourite(product: Product)`

 передает на сервер информацию об исключении товара из избранного (событие "productDislike")

- `productOpen (product: Product)`

- передает на сервер информацию об открытии карточки товара (событие "productOpen")

В параметры данных методов передаётся структура Product:

 ```swift
  public struct Product {

   public var id: String? = nil,
   public var categoryId: String? = nil,
   public var count: Int? = nil,
   public var price: String? = nil,
   public var picture: String? = nil,
   public var params: [String:Any]? = nil

 }
 ```

-поле id - обязательное для фиксации события и должно быть указано.
-опционально: для передачи дополнительных параметров которые не подходят не к одному из уже добавленных в класс полей
можно передать в качестве параметра "params" словарь [String:Any] содержащий необходимые ключи и значения

- `productBuy (orders: [Order], orderId: String? = nil, orderDatetime: String? = nil, orderParams: [String:Any]? = nil)`

- передает на сервер информацию о покупке товара / товаров (событие "order")

Функция включает следующие параметры:

orders: [Order] - данный параметр принимает массив структур Order

orderId: String? = nil  -  в данный параметр можно передать номер заказа в формате String (по умолчанию nil), при значении параметра равного nil,

метод сгенерирует случайный уникальный номер заказа в формате String и передаст его на сервер.

orderDatetime: String? = nil  - в данный параметр можно передать время заказа в формате String (по умолчанию nil).

orderParams: [String:Any]? = nil -  в данный метод можно передать дополнительную информацию для заказа с помощью словаря [String:Any],

указав соответствующие ключи и значения.

 ```swift
  public struct Order {

    public var id: String? = nil,
    public var count: Int? = nil,
    public var price: String? = nil,
    public var params: [String:Any]? = nil

  }
 ```
опционально: для передачи дополнительных параметров для конкретной позиции можно передать в качестве параметра params:

словарь [String: Any] содержащую необходимые ключи и значения.



