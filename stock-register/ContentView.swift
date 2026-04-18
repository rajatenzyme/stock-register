import SwiftUI
import Charts
import PDFKit
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - Brand Colors
extension Color {
    static let gpOrange      = Color(red: 1.0,  green: 0.55, blue: 0.11)
    static let gpOrangeDark  = Color(red: 0.88, green: 0.38, blue: 0.04)
    static let gpOrangeLight = Color(red: 1.0,  green: 0.55, blue: 0.11).opacity(0.12)
}

// MARK: - Notification Record

struct NotificationRecord: Identifiable, Codable {
    var id = UUID()
    var title: String
    var body: String
    var date: Date
    var isRead: Bool = false
}

// MARK: - App Settings (Theme, Language & Notification History)

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    @Published var theme: String {
        didSet { UserDefaults.standard.set(theme, forKey: "appTheme") }
    }
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "appLanguage") }
    }
    @Published var notifications: [NotificationRecord] = []

    init() {
        self.theme    = UserDefaults.standard.string(forKey: "appTheme")    ?? "system"
        self.language = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        if let data = UserDefaults.standard.data(forKey: "appNotifications"),
           let saved = try? JSONDecoder().decode([NotificationRecord].self, from: data) {
            self.notifications = saved
        }
    }

    var colorScheme: ColorScheme? {
        switch theme {
        case "light":  return .light
        case "dark":   return .dark
        default:       return nil
        }
    }

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    func addNotification(title: String, body: String) {
        let record = NotificationRecord(title: title, body: body, date: Date())
        notifications.insert(record, at: 0)
        if notifications.count > 100 { notifications = Array(notifications.prefix(100)) }
        saveNotifications()
    }

    func markAllRead() {
        notifications = notifications.map { var n = $0; n.isRead = true; return n }
        saveNotifications()
    }

    func savePublicNotifications() {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: "appNotifications")
        }
    }

    private func saveNotifications() { savePublicNotifications() }
}

// MARK: - Localisation

func t(_ key: String) -> String {
    let lang = AppSettings.shared.language
    return translations[lang]?[key] ?? translations["en"]?[key] ?? key
}

let translations: [String: [String: String]] = [
    "en": [
        "tab.home": "Home", "tab.stock": "Stock", "tab.items": "Items",
        "tab.transactions": "Transactions", "tab.settings": "Settings",
        "home.tagline": "Aapka Godown, Aapki Muthi Mein", "home.whyTitle": "Why GodownPe?",
        "feature.liveTracking": "Live Stock Tracking",
        "feature.liveTrackingDesc": "Real-time inventory updates with zero delays",
        "feature.multiLocation": "Multiple Locations",
        "feature.multiLocationDesc": "Manage all your shops from one place",
        "feature.reports": "Instant Reports",
        "feature.reportsDesc": "Generate professional PDFs in seconds",
        "feature.history": "Complete History",
        "feature.historyDesc": "Every transaction tracked automatically",
        "feature.secure": "Secure & Private", "feature.secureDesc": "Google-powered data protection",
        "feature.profit": "Profit Tracking", "feature.profitDesc": "See your margins and profits clearly",
        "dash.totalProfit": "Total Profit", "dash.totalPurchase": "Total Purchase",
        "dash.totalSales": "Total Sales", "dash.reportsLink": "Reports →",
        "dash.summaryLink": "Detailed Summary →", "dash.searchItems": "Search items",
        "dash.allGodowns": "All Godowns", "dash.items": "items",
        "period.daily": "Daily", "period.weekly": "Weekly", "period.monthly": "Monthly", "period.yearly": "Yearly",
        "stock.totalStockIn": "Total Stock In", "stock.openingStock": "Opening Stock",
        "stock.totalStockOut": "Total Stock Out", "stock.remainingStock": "Remaining Stock",
        "stock.updatedRecently": "Updated recently", "stock.btnIn": "In", "stock.btnOut": "Out",
        "txn.title": "Transactions", "txn.search": "Search transactions",
        "txn.units": "units", "txn.profit": "Profit",
        "report.title": "Reports", "report.dailySales": "Daily Sales",
        "report.monthlySales": "Monthly Sales", "report.yearlySales": "Yearly Sales",
        "report.stockSummary": "Stock Summary", "report.lowStock": "Low Stock Items",
        "report.profitLoss": "Profit & Loss", "report.salesReports": "Sales Reports",
        "report.stockReports": "Stock Reports", "report.financialReports": "Financial Reports",
        "report.allGodowns": "All Godowns", "report.exportPDF": "Export PDF",
        "report.totalTransactions": "Total Transactions", "report.totalSalesAmount": "Total Sales Amount",
        "report.outOfStock": "Out of Stock",
        "pdf.item": "Item", "pdf.qty": "Qty", "pdf.unit": "Unit", "pdf.pricePerUnit": "Price/Unit",
        "pdf.amount": "Amount", "pdf.total": "Total", "pdf.opening": "Opening",
        "pdf.currStock": "Curr.Stock", "pdf.purchaseVal": "Purchase ₹", "pdf.value": "Value ₹",
        "pdf.currentStock": "Current Stock", "pdf.sellPrice": "Sell Price",
        "pdf.purchase": "Purchase", "pdf.profit": "Profit", "pdf.date": "Date",
        "pdf.allGodowns": "All Godowns", "pdf.summary": "Summary",
        "summary.title": "Detailed Summary", "summary.allGodowns": "Summary (All Godowns)",
        "summary.recentTxns": "Recent Transactions (All Godowns)",
        "summary.totalItems": "Total Items", "summary.totalStockValue": "Total Stock Value",
        "summary.totalPurchase": "Total Purchase", "summary.totalSales": "Total Sales",
        "summary.netProfit": "Net Profit",
        "items.title": "Items", "items.allItems": "All Items", "items.searchItems": "Search items",
        "items.stockIn": "Stock In", "items.stockOut": "Stock Out",
        "item.addItem": "Add Item", "item.itemDetails": "Item Details",
        "item.itemNamePlaceholder": "Item Name *", "item.noGodowns": "No godowns available.",
        "item.godownCategory": "Godown (Category)", "item.godownHeader": "Godown / Category",
        "item.pricing": "Pricing", "item.purchasePrice": "Purchase Price",
        "item.mrp": "MRP (Maximum Retail Price)", "item.priceUnit": "Price Unit",
        "item.stock": "Stock", "item.openingStock": "Opening Stock *",
        "item.info": "Item Information", "item.name": "Name",
        "item.purchasePriceLabel": "Purchase Price", "item.mrpLabel": "MRP",
        "item.sellingPrice": "Selling Price", "item.priceUnitLabel": "Price Unit",
        "item.openingStockLabel": "Opening Stock", "item.currentStockLabel": "Current Stock",
        "item.stockMovements": "Stock Movements", "item.totalStockIn": "Total Stock In",
        "item.totalStockOut": "Total Stock Out", "item.stockInLabel": "Stock In",
        "item.stockOutLabel": "Stock Out", "item.editItem": "Edit Item",
        "item.deleteItem": "Delete Item",
        "item.deleteConfirm": "Are you sure you want to delete '%@'? This action cannot be undone.",
        "item.itemName": "Item Name", "item.editItemTitle": "Edit Item",
        "stockUpdate.qty": "Quantity", "stockUpdate.priceOptional": "Price per unit (optional)",
        "stockUpdate.currentStock": "Current Stock", "stockUpdate.purchasePrice": "Purchase Price",
        "stockUpdate.mrp": "MRP", "stockUpdate.sellingPrice": "Selling Price",
        "stockUpdate.insufficientStock": "⚠️ Insufficient stock. Available",
        "stockUpdate.errorMsg": "Insufficient stock. Cannot go negative.",
        "settings.title": "Settings", "settings.businessProfile": "Business Profile",
        "settings.businessNamePlaceholder": "Business Name",
        "settings.businessAddressPlaceholder": "Business Address",
        "settings.setBusinessName": "Set business name…", "settings.setAddress": "Set address…",
        "settings.addressLabel": "Address", "settings.godowns": "Godowns",
        "settings.addGodown": "Add Godown", "settings.support": "Support",
        "settings.appSupport": "App Support", "settings.about": "About",
        "settings.privacy": "Privacy Policy", "settings.terms": "Terms of Service",
        "settings.appearance": "Appearance", "settings.theme": "Theme", "settings.language": "Language",
        "theme.system": "System Default", "theme.light": "Light", "theme.dark": "Dark",
        "lang.en": "English", "lang.hi": "हिन्दी", "lang.mr": "मराठी", "lang.gu": "ગુજરાતી", "lang.pa": "ਪੰਜਾਬੀ",
        "action.save": "Save", "action.edit": "Edit", "action.cancel": "Cancel",
        "action.delete": "Delete", "action.ok": "OK",
        "auth.signIn": "Sign in with Google", "auth.syncData": "Sync your data across devices",
        "auth.signOut": "Sign Out", "auth.signOutConfirm": "Are you sure you want to sign out?",
        "auth.signInTitle": "Sign In", "auth.welcomeBack": "Welcome Back!",
        "auth.signInDesc": "Sign in to sync your godown data\nacross all your devices",
        "auth.continueWithGoogle": "Continue with Google",
        "auth.dataPrivate": "Your business data is private and protected",
        "auth.error": "Error",
        "cat.addCategory": "Add Category", "cat.categoryDetails": "Category Details",
        "cat.categoryNamePlaceholder": "Category Name",
        "myBusiness": "My Business",
        "noDataAvailable": "No data available for this report.",
        "noLowStock": "No low stock items.",
        "report.selectDate": "Select Date", "report.selectMonth": "Select Month", "report.selectYear": "Select Year",
        "item.godownLabel": "Godown", "item.noTransactions": "No transactions yet",
        "item.lowStockThreshold": "Low Stock Alert",
        "item.lowStockThresholdHint": "Alert when stock falls to or below this quantity (default: 20% of opening stock)",
        "item.lowStockAlert": "Low Stock Alert",
        "item.lowStockRemaining": "remaining — running low!",
        "notifications.title": "Notifications", "notifications.empty": "No notifications yet",
        "notifications.done": "Done", "notifications.clearAll": "Clear All",
        "report.productAnalysis": "Product Analysis",
        "analysis.selectItem": "Select an item", "analysis.noData": "Select an item to view its sales & purchase analysis",
        "analysis.quantity": "Quantity", "analysis.value": "Value (₹)",
    ],
    "hi": [
        "tab.home": "होम", "tab.stock": "स्टॉक", "tab.items": "वस्तुएं",
        "tab.transactions": "लेनदेन", "tab.settings": "सेटिंग",
        "home.tagline": "आपका गोदाम, आपकी मुट्ठी में", "home.whyTitle": "GodownPe क्यों?",
        "feature.liveTracking": "लाइव स्टॉक ट्रैकिंग",
        "feature.liveTrackingDesc": "बिना देरी रियल-टाइम इन्वेंटरी अपडेट",
        "feature.multiLocation": "अनेक स्थान",
        "feature.multiLocationDesc": "एक जगह से सभी दुकानों का प्रबंधन करें",
        "feature.reports": "तुरंत रिपोर्ट",
        "feature.reportsDesc": "सेकंडों में पेशेवर PDF बनाएं",
        "feature.history": "पूरा इतिहास",
        "feature.historyDesc": "हर लेनदेन स्वचालित ट्रैक किया जाता है",
        "feature.secure": "सुरक्षित और निजी", "feature.secureDesc": "Google-संचालित डेटा सुरक्षा",
        "feature.profit": "लाभ ट्रैकिंग", "feature.profitDesc": "अपने मार्जिन और लाभ स्पष्ट रूप से देखें",
        "dash.totalProfit": "कुल लाभ", "dash.totalPurchase": "कुल खरीद",
        "dash.totalSales": "कुल बिक्री", "dash.reportsLink": "रिपोर्ट →",
        "dash.summaryLink": "विस्तृत सारांश →", "dash.searchItems": "वस्तुएं खोजें",
        "dash.allGodowns": "सभी गोदाम", "dash.items": "वस्तुएं",
        "period.daily": "दैनिक", "period.weekly": "साप्ताहिक", "period.monthly": "मासिक", "period.yearly": "वार्षिक",
        "stock.totalStockIn": "कुल स्टॉक इन", "stock.openingStock": "प्रारंभिक स्टॉक",
        "stock.totalStockOut": "कुल स्टॉक आउट", "stock.remainingStock": "शेष स्टॉक",
        "stock.updatedRecently": "हाल ही में अपडेट", "stock.btnIn": "इन", "stock.btnOut": "आउट",
        "txn.title": "लेनदेन", "txn.search": "लेनदेन खोजें",
        "txn.units": "इकाइयां", "txn.profit": "लाभ",
        "report.title": "रिपोर्ट", "report.dailySales": "दैनिक बिक्री",
        "report.monthlySales": "मासिक बिक्री", "report.yearlySales": "वार्षिक बिक्री",
        "report.stockSummary": "स्टॉक सारांश", "report.lowStock": "कम स्टॉक वस्तुएं",
        "report.profitLoss": "लाभ & हानि", "report.salesReports": "बिक्री रिपोर्ट",
        "report.stockReports": "स्टॉक रिपोर्ट", "report.financialReports": "वित्तीय रिपोर्ट",
        "report.allGodowns": "सभी गोदाम", "report.exportPDF": "PDF निर्यात",
        "report.totalTransactions": "कुल लेनदेन", "report.totalSalesAmount": "कुल बिक्री राशि",
        "report.outOfStock": "स्टॉक खत्म",
        "pdf.item": "वस्तु", "pdf.qty": "मात्रा", "pdf.unit": "इकाई", "pdf.pricePerUnit": "मूल्य/इकाई",
        "pdf.amount": "राशि", "pdf.total": "कुल", "pdf.opening": "प्रारंभिक",
        "pdf.currStock": "वर्त.स्टॉक", "pdf.purchaseVal": "खरीद ₹", "pdf.value": "मूल्य ₹",
        "pdf.currentStock": "वर्तमान स्टॉक", "pdf.sellPrice": "बिक्री मूल्य",
        "pdf.purchase": "खरीद", "pdf.profit": "लाभ", "pdf.date": "तारीख",
        "pdf.allGodowns": "सभी गोदाम", "pdf.summary": "सारांश",
        "summary.title": "विस्तृत सारांश", "summary.allGodowns": "सारांश (सभी गोदाम)",
        "summary.recentTxns": "हाल के लेनदेन (सभी गोदाम)",
        "summary.totalItems": "कुल वस्तुएं", "summary.totalStockValue": "कुल स्टॉक मूल्य",
        "summary.totalPurchase": "कुल खरीद", "summary.totalSales": "कुल बिक्री",
        "summary.netProfit": "शुद्ध लाभ",
        "items.title": "वस्तुएं", "items.allItems": "सभी वस्तुएं", "items.searchItems": "वस्तुएं खोजें",
        "items.stockIn": "स्टॉक इन", "items.stockOut": "स्टॉक आउट",
        "item.addItem": "वस्तु जोड़ें", "item.itemDetails": "वस्तु विवरण",
        "item.itemNamePlaceholder": "वस्तु का नाम *", "item.noGodowns": "कोई गोदाम उपलब्ध नहीं।",
        "item.godownCategory": "गोदाम (श्रेणी)", "item.godownHeader": "गोदाम / श्रेणी",
        "item.pricing": "मूल्य निर्धारण", "item.purchasePrice": "खरीद मूल्य",
        "item.mrp": "एमआरपी (अधिकतम खुदरा मूल्य)", "item.priceUnit": "मूल्य इकाई",
        "item.stock": "स्टॉक", "item.openingStock": "प्रारंभिक स्टॉक *",
        "item.info": "वस्तु जानकारी", "item.name": "नाम",
        "item.purchasePriceLabel": "खरीद मूल्य", "item.mrpLabel": "एमआरपी",
        "item.sellingPrice": "बिक्री मूल्य", "item.priceUnitLabel": "मूल्य इकाई",
        "item.openingStockLabel": "प्रारंभिक स्टॉक", "item.currentStockLabel": "वर्तमान स्टॉक",
        "item.stockMovements": "स्टॉक आवाजाही", "item.totalStockIn": "कुल स्टॉक इन",
        "item.totalStockOut": "कुल स्टॉक आउट", "item.stockInLabel": "स्टॉक इन",
        "item.stockOutLabel": "स्टॉक आउट", "item.editItem": "वस्तु संपादित करें",
        "item.deleteItem": "वस्तु हटाएं",
        "item.deleteConfirm": "क्या आप '%@' को हटाना चाहते हैं? यह क्रिया पूर्ववत नहीं की जा सकती।",
        "item.itemName": "वस्तु का नाम", "item.editItemTitle": "वस्तु संपादित करें",
        "stockUpdate.qty": "मात्रा", "stockUpdate.priceOptional": "मूल्य प्रति इकाई (वैकल्पिक)",
        "stockUpdate.currentStock": "वर्तमान स्टॉक", "stockUpdate.purchasePrice": "खरीद मूल्य",
        "stockUpdate.mrp": "एमआरपी", "stockUpdate.sellingPrice": "बिक्री मूल्य",
        "stockUpdate.insufficientStock": "⚠️ अपर्याप्त स्टॉक। उपलब्ध",
        "stockUpdate.errorMsg": "अपर्याप्त स्टॉक। नकारात्मक नहीं जा सकता।",
        "settings.title": "सेटिंग", "settings.businessProfile": "व्यापार प्रोफाइल",
        "settings.businessNamePlaceholder": "व्यापार का नाम",
        "settings.businessAddressPlaceholder": "व्यापार का पता",
        "settings.setBusinessName": "व्यापार का नाम दर्ज करें…",
        "settings.setAddress": "पता दर्ज करें…", "settings.addressLabel": "पता",
        "settings.godowns": "गोदाम", "settings.addGodown": "गोदाम जोड़ें",
        "settings.support": "सहायता", "settings.appSupport": "ऐप सहायता",
        "settings.about": "के बारे में", "settings.privacy": "गोपनीयता नीति",
        "settings.terms": "सेवा की शर्तें", "settings.appearance": "दिखावट",
        "settings.theme": "थीम", "settings.language": "भाषा",
        "theme.system": "सिस्टम डिफ़ॉल्ट", "theme.light": "हल्का", "theme.dark": "गहरा",
        "lang.en": "English", "lang.hi": "हिन्दी", "lang.mr": "मराठी", "lang.gu": "ગુજરાતી", "lang.pa": "ਪੰਜਾਬੀ",
        "action.save": "सहेजें", "action.edit": "संपादित करें", "action.cancel": "रद्द करें",
        "action.delete": "हटाएं", "action.ok": "ठीक है",
        "auth.signIn": "Google से साइन इन करें", "auth.syncData": "सभी डिवाइस में डेटा सिंक करें",
        "auth.signOut": "साइन आउट", "auth.signOutConfirm": "क्या आप साइन आउट करना चाहते हैं?",
        "auth.signInTitle": "साइन इन", "auth.welcomeBack": "वापसी पर स्वागत!",
        "auth.signInDesc": "अपने गोदाम डेटा को सभी डिवाइस में\nसिंक करने के लिए साइन इन करें",
        "auth.continueWithGoogle": "Google से जारी रखें",
        "auth.dataPrivate": "आपका व्यापार डेटा निजी और सुरक्षित है",
        "auth.error": "त्रुटि",
        "cat.addCategory": "श्रेणी जोड़ें", "cat.categoryDetails": "श्रेणी विवरण",
        "cat.categoryNamePlaceholder": "श्रेणी का नाम",
        "myBusiness": "मेरा व्यापार",
        "noDataAvailable": "इस रिपोर्ट के लिए कोई डेटा उपलब्ध नहीं है।",
        "noLowStock": "कम स्टॉक वाली कोई वस्तु नहीं।",
        "report.selectDate": "तारीख चुनें", "report.selectMonth": "महीना चुनें", "report.selectYear": "वर्ष चुनें",
        "item.godownLabel": "गोदाम", "item.noTransactions": "अभी तक कोई लेनदेन नहीं",
        "item.lowStockThreshold": "कम स्टॉक अलर्ट",
        "item.lowStockThresholdHint": "इस मात्रा तक पहुंचने पर सूचना (डिफ़ॉल्ट: प्रारंभिक स्टॉक का 20%)",
        "item.lowStockAlert": "कम स्टॉक अलर्ट",
        "item.lowStockRemaining": "शेष — स्टॉक कम है!",
        "notifications.title": "सूचनाएं", "notifications.empty": "अभी तक कोई सूचना नहीं",
        "notifications.done": "हो गया", "notifications.clearAll": "सब हटाएं",
        "report.productAnalysis": "उत्पाद विश्लेषण",
        "analysis.selectItem": "वस्तु चुनें", "analysis.noData": "विश्लेषण देखने के लिए वस्तु चुनें",
        "analysis.quantity": "मात्रा", "analysis.value": "मूल्य (₹)",
    ],
    "mr": [
        "tab.home": "होम", "tab.stock": "साठा", "tab.items": "वस्तू",
        "tab.transactions": "व्यवहार", "tab.settings": "सेटिंग्ज",
        "home.tagline": "तुमचा गोदाम, तुमच्या मुठीत", "home.whyTitle": "GodownPe का?",
        "feature.liveTracking": "थेट साठा ट्रॅकिंग",
        "feature.liveTrackingDesc": "शून्य विलंबाने रिअल-टाइम इन्व्हेंटरी अपडेट",
        "feature.multiLocation": "अनेक स्थाने",
        "feature.multiLocationDesc": "एका ठिकाणाहून सर्व दुकाने व्यवस्थापित करा",
        "feature.reports": "त्वरित अहवाल",
        "feature.reportsDesc": "सेकंदात व्यावसायिक PDF तयार करा",
        "feature.history": "संपूर्ण इतिहास",
        "feature.historyDesc": "प्रत्येक व्यवहार आपोआप ट्रॅक केला जातो",
        "feature.secure": "सुरक्षित आणि खाजगी", "feature.secureDesc": "Google-चालित डेटा संरक्षण",
        "feature.profit": "नफा ट्रॅकिंग", "feature.profitDesc": "तुमचे मार्जिन आणि नफा स्पष्टपणे पाहा",
        "dash.totalProfit": "एकूण नफा", "dash.totalPurchase": "एकूण खरेदी",
        "dash.totalSales": "एकूण विक्री", "dash.reportsLink": "अहवाल →",
        "dash.summaryLink": "सविस्तर सारांश →", "dash.searchItems": "वस्तू शोधा",
        "dash.allGodowns": "सर्व गोदाम", "dash.items": "वस्तू",
        "period.daily": "दैनिक", "period.weekly": "साप्ताहिक", "period.monthly": "मासिक", "period.yearly": "वार्षिक",
        "stock.totalStockIn": "एकूण साठा आत", "stock.openingStock": "प्रारंभिक साठा",
        "stock.totalStockOut": "एकूण साठा बाहेर", "stock.remainingStock": "उर्वरित साठा",
        "stock.updatedRecently": "नुकतेच अपडेट केले", "stock.btnIn": "आत", "stock.btnOut": "बाहेर",
        "txn.title": "व्यवहार", "txn.search": "व्यवहार शोधा",
        "txn.units": "एकके", "txn.profit": "नफा",
        "report.title": "अहवाल", "report.dailySales": "दैनिक विक्री",
        "report.monthlySales": "मासिक विक्री", "report.yearlySales": "वार्षिक विक्री",
        "report.stockSummary": "साठा सारांश", "report.lowStock": "कमी साठा वस्तू",
        "report.profitLoss": "नफा & नुकसान", "report.salesReports": "विक्री अहवाल",
        "report.stockReports": "साठा अहवाल", "report.financialReports": "आर्थिक अहवाल",
        "report.allGodowns": "सर्व गोदाम", "report.exportPDF": "PDF निर्यात करा",
        "report.totalTransactions": "एकूण व्यवहार", "report.totalSalesAmount": "एकूण विक्री रक्कम",
        "report.outOfStock": "साठा संपला",
        "pdf.item": "वस्तू", "pdf.qty": "प्रमाण", "pdf.unit": "एकक", "pdf.pricePerUnit": "किंमत/एकक",
        "pdf.amount": "रक्कम", "pdf.total": "एकूण", "pdf.opening": "प्रारंभिक",
        "pdf.currStock": "सध्या.साठा", "pdf.purchaseVal": "खरेदी ₹", "pdf.value": "मूल्य ₹",
        "pdf.currentStock": "सध्याचा साठा", "pdf.sellPrice": "विक्री किंमत",
        "pdf.purchase": "खरेदी", "pdf.profit": "नफा", "pdf.date": "तारीख",
        "pdf.allGodowns": "सर्व गोदाम", "pdf.summary": "सारांश",
        "summary.title": "सविस्तर सारांश", "summary.allGodowns": "सारांश (सर्व गोदाम)",
        "summary.recentTxns": "अलीकडील व्यवहार (सर्व गोदाम)",
        "summary.totalItems": "एकूण वस्तू", "summary.totalStockValue": "एकूण साठा मूल्य",
        "summary.totalPurchase": "एकूण खरेदी", "summary.totalSales": "एकूण विक्री",
        "summary.netProfit": "निव्वळ नफा",
        "items.title": "वस्तू", "items.allItems": "सर्व वस्तू", "items.searchItems": "वस्तू शोधा",
        "items.stockIn": "साठा आत", "items.stockOut": "साठा बाहेर",
        "item.addItem": "वस्तू जोडा", "item.itemDetails": "वस्तू तपशील",
        "item.itemNamePlaceholder": "वस्तूचे नाव *", "item.noGodowns": "कोणतेही गोदाम उपलब्ध नाही.",
        "item.godownCategory": "गोदाम (श्रेणी)", "item.godownHeader": "गोदाम / श्रेणी",
        "item.pricing": "किंमत निर्धारण", "item.purchasePrice": "खरेदी किंमत",
        "item.mrp": "एमआरपी (कमाल किरकोळ किंमत)", "item.priceUnit": "किंमत एकक",
        "item.stock": "साठा", "item.openingStock": "प्रारंभिक साठा *",
        "item.info": "वस्तू माहिती", "item.name": "नाव",
        "item.purchasePriceLabel": "खरेदी किंमत", "item.mrpLabel": "एमआरपी",
        "item.sellingPrice": "विक्री किंमत", "item.priceUnitLabel": "किंमत एकक",
        "item.openingStockLabel": "प्रारंभिक साठा", "item.currentStockLabel": "सध्याचा साठा",
        "item.stockMovements": "साठा हालचाल", "item.totalStockIn": "एकूण साठा आत",
        "item.totalStockOut": "एकूण साठा बाहेर", "item.stockInLabel": "साठा आत",
        "item.stockOutLabel": "साठा बाहेर", "item.editItem": "वस्तू संपादित करा",
        "item.deleteItem": "वस्तू हटवा",
        "item.deleteConfirm": "'%@' हटवायचे आहे का? ही क्रिया पूर्वत करता येणार नाही.",
        "item.itemName": "वस्तूचे नाव", "item.editItemTitle": "वस्तू संपादित करा",
        "stockUpdate.qty": "प्रमाण", "stockUpdate.priceOptional": "किंमत प्रति एकक (पर्यायी)",
        "stockUpdate.currentStock": "सध्याचा साठा", "stockUpdate.purchasePrice": "खरेदी किंमत",
        "stockUpdate.mrp": "एमआरपी", "stockUpdate.sellingPrice": "विक्री किंमत",
        "stockUpdate.insufficientStock": "⚠️ अपुरा साठा. उपलब्ध",
        "stockUpdate.errorMsg": "अपुरा साठा. नकारात्मक जाऊ शकत नाही.",
        "settings.title": "सेटिंग्ज", "settings.businessProfile": "व्यवसाय प्रोफाइल",
        "settings.businessNamePlaceholder": "व्यवसायाचे नाव",
        "settings.businessAddressPlaceholder": "व्यवसायाचा पत्ता",
        "settings.setBusinessName": "व्यवसायाचे नाव टाका…",
        "settings.setAddress": "पत्ता टाका…", "settings.addressLabel": "पत्ता",
        "settings.godowns": "गोदाम", "settings.addGodown": "गोदाम जोडा",
        "settings.support": "समर्थन", "settings.appSupport": "अ‍ॅप समर्थन",
        "settings.about": "आमच्याबद्दल", "settings.privacy": "गोपनीयता धोरण",
        "settings.terms": "सेवेच्या अटी", "settings.appearance": "देखावा",
        "settings.theme": "थीम", "settings.language": "भाषा",
        "theme.system": "सिस्टम डीफॉल्ट", "theme.light": "हलका", "theme.dark": "गडद",
        "lang.en": "English", "lang.hi": "हिन्दी", "lang.mr": "मराठी", "lang.gu": "ગુજરાતી", "lang.pa": "ਪੰਜਾਬੀ",
        "action.save": "जतन करा", "action.edit": "संपादित करा", "action.cancel": "रद्द करा",
        "action.delete": "हटवा", "action.ok": "ठीक आहे",
        "auth.signIn": "Google ने साइन इन करा", "auth.syncData": "सर्व डिव्हाइसवर डेटा सिंक करा",
        "auth.signOut": "साइन आउट", "auth.signOutConfirm": "तुम्हाला साइन आउट करायचे आहे का?",
        "auth.signInTitle": "साइन इन", "auth.welcomeBack": "परत आलात, स्वागत!",
        "auth.signInDesc": "तुमच्या गोदाम डेटाला सर्व डिव्हाइसवर\nसिंक करण्यासाठी साइन इन करा",
        "auth.continueWithGoogle": "Google ने सुरू ठेवा",
        "auth.dataPrivate": "तुमचा व्यवसाय डेटा खाजगी आणि सुरक्षित आहे",
        "auth.error": "त्रुटी",
        "cat.addCategory": "श्रेणी जोडा", "cat.categoryDetails": "श्रेणी तपशील",
        "cat.categoryNamePlaceholder": "श्रेणीचे नाव",
        "myBusiness": "माझा व्यवसाय",
        "noDataAvailable": "या अहवालासाठी कोणताही डेटा उपलब्ध नाही.",
        "noLowStock": "कमी साठ्याच्या वस्तू नाहीत.",
        "report.selectDate": "तारीख निवडा", "report.selectMonth": "महिना निवडा", "report.selectYear": "वर्ष निवडा",
        "item.godownLabel": "गोदाम", "item.noTransactions": "अद्याप कोणतेही व्यवहार नाहीत",
        "item.lowStockThreshold": "कमी साठा सूचना",
        "item.lowStockThresholdHint": "या प्रमाणापर्यंत साठा आल्यास सूचना (डीफॉल्ट: प्रारंभिक साठ्याच्या 20%)",
        "item.lowStockAlert": "कमी साठा सूचना",
        "item.lowStockRemaining": "शिल्लक — साठा कमी होत आहे!",
        "notifications.title": "सूचना", "notifications.empty": "अद्याप कोणतीही सूचना नाही",
        "notifications.done": "झाले", "notifications.clearAll": "सर्व हटवा",
        "report.productAnalysis": "उत्पाद विश्लेषण",
        "analysis.selectItem": "वस्तू निवडा", "analysis.noData": "विश्लेषण पाहण्यासाठी वस्तू निवडा",
        "analysis.quantity": "प्रमाण", "analysis.value": "मूल्य (₹)",
    ],
    "gu": [
        "tab.home": "હોમ", "tab.stock": "સ્ટૉક", "tab.items": "વસ્તુઓ",
        "tab.transactions": "વ્યવહારો", "tab.settings": "સેટિંગ",
        "home.tagline": "તમારો ગોડાઉન, તમારી મુઠ્ઠીમાં", "home.whyTitle": "GodownPe કેમ?",
        "feature.liveTracking": "લાઇવ સ્ટૉક ટ્રૅકિંગ",
        "feature.liveTrackingDesc": "શૂન્ય વિલંબ સાથે રિઅલ-ટાઇમ ઇન્વેન્ટ્રી અપડેટ",
        "feature.multiLocation": "અનેક સ્થળો",
        "feature.multiLocationDesc": "એક જ જગ્યાએ બધી દુકાનો સંભાળો",
        "feature.reports": "ઝડપી રિપોર્ટ",
        "feature.reportsDesc": "સેકન્ડોમાં પ્રોફેશ્નલ PDF બનાવો",
        "feature.history": "સંપૂર્ણ ઇતિહાસ",
        "feature.historyDesc": "દરેક વ્યવહાર આપોઆપ ટ્રૅક",
        "feature.secure": "સુરક્ષિત અને ખાનગી", "feature.secureDesc": "Google-સંચાલિત ડેટા સુરક્ષા",
        "feature.profit": "નફો ટ્રૅકિંગ", "feature.profitDesc": "તમારા માર્જિન અને નફો સ્પષ્ટ રીતે જુઓ",
        "dash.totalProfit": "કુલ નફો", "dash.totalPurchase": "કુલ ખરીદ",
        "dash.totalSales": "કુલ વેચાણ", "dash.reportsLink": "રિપોર્ટ →",
        "dash.summaryLink": "વિગતવાર સારાંશ →", "dash.searchItems": "વસ્તુઓ શોધો",
        "dash.allGodowns": "બધા ગોડાઉન", "dash.items": "વસ્તુઓ",
        "period.daily": "દૈનિક", "period.weekly": "સાપ્તાહિક", "period.monthly": "માસિક", "period.yearly": "વાર્ષિક",
        "stock.totalStockIn": "કુલ સ્ટૉક ઇન", "stock.openingStock": "ઉઘાડ સ્ટૉક",
        "stock.totalStockOut": "કુલ સ્ટૉક આઉટ", "stock.remainingStock": "બાકી સ્ટૉક",
        "stock.updatedRecently": "હમણાં અપડેટ", "stock.btnIn": "ઇન", "stock.btnOut": "આઉટ",
        "txn.title": "વ્યવહારો", "txn.search": "વ્યવહારો શોધો",
        "txn.units": "એકમો", "txn.profit": "નફો",
        "report.title": "રિપોર્ટ", "report.dailySales": "દૈનિક વેચાણ",
        "report.monthlySales": "માસિક વેચાણ", "report.yearlySales": "વાર્ષિક વેચાણ",
        "report.stockSummary": "સ્ટૉક સારાંશ", "report.lowStock": "ઓછો સ્ટૉક",
        "report.profitLoss": "નફો & નુકસાન", "report.salesReports": "વેચાણ રિપોર્ટ",
        "report.stockReports": "સ્ટૉક રિપોર્ટ", "report.financialReports": "આર્થિક રિપોર્ટ",
        "report.allGodowns": "બધા ગોડાઉન", "report.exportPDF": "PDF નિકાસ",
        "report.totalTransactions": "કુલ વ્યવહારો", "report.totalSalesAmount": "કુલ વેચાણ રકમ",
        "report.outOfStock": "સ્ટૉક ખત્મ",
        "pdf.item": "વસ્તુ", "pdf.qty": "જથ્થો", "pdf.unit": "એકમ", "pdf.pricePerUnit": "ભાવ/એકમ",
        "pdf.amount": "રકમ", "pdf.total": "કુલ", "pdf.opening": "ઉઘાડ",
        "pdf.currStock": "હાલ.સ્ટૉક", "pdf.purchaseVal": "ખરીદ ₹", "pdf.value": "મૂલ્ય ₹",
        "pdf.currentStock": "હાલ સ્ટૉક", "pdf.sellPrice": "વેચ ભાવ",
        "pdf.purchase": "ખરીદ", "pdf.profit": "નફો", "pdf.date": "તારીખ",
        "pdf.allGodowns": "બધા ગોડાઉન", "pdf.summary": "સારાંશ",
        "summary.title": "વિગતવાર સારાંશ", "summary.allGodowns": "સારાંશ (બધા ગોડાઉન)",
        "summary.recentTxns": "તાજેતરના વ્યવહારો (બધા ગોડાઉન)",
        "summary.totalItems": "કુલ વસ્તુઓ", "summary.totalStockValue": "કુલ સ્ટૉક મૂલ્ય",
        "summary.totalPurchase": "કુલ ખરીદ", "summary.totalSales": "કુલ વેચાણ",
        "summary.netProfit": "ચોખ્ખો નફો",
        "items.title": "વસ્તુઓ", "items.allItems": "બધી વસ્તુઓ", "items.searchItems": "વસ્તુઓ શોધો",
        "items.stockIn": "સ્ટૉક ઇન", "items.stockOut": "સ્ટૉક આઉટ",
        "item.addItem": "વસ્તુ ઉમેરો", "item.itemDetails": "વસ્તુ વિગત",
        "item.itemNamePlaceholder": "વસ્તુ નું નામ *", "item.noGodowns": "કોઈ ગોડાઉન ઉપલબ્ધ નથી.",
        "item.godownCategory": "ગોડાઉન (શ્રેણી)", "item.godownHeader": "ગોડાઉન / શ્રેણી",
        "item.pricing": "ભાવ નિર્ધારણ", "item.purchasePrice": "ખરીદ ભાવ",
        "item.mrp": "MRP (મહત્તમ છૂટક ભાવ)", "item.priceUnit": "ભાવ એકમ",
        "item.stock": "સ્ટૉક", "item.openingStock": "ઉઘાડ સ્ટૉક *",
        "item.info": "વસ્તુ માહિતી", "item.name": "નામ",
        "item.purchasePriceLabel": "ખરીદ ભાવ", "item.mrpLabel": "MRP",
        "item.sellingPrice": "વેચ ભાવ", "item.priceUnitLabel": "ભાવ એકમ",
        "item.openingStockLabel": "ઉઘાડ સ્ટૉક", "item.currentStockLabel": "હાલ સ્ટૉક",
        "item.stockMovements": "સ્ટૉક ફેરફાર", "item.totalStockIn": "કુલ સ્ટૉક ઇન",
        "item.totalStockOut": "કુલ સ્ટૉક આઉટ", "item.stockInLabel": "સ્ટૉક ઇન",
        "item.stockOutLabel": "સ્ટૉક આઉટ", "item.editItem": "વસ્તુ સંપાદિત કરો",
        "item.deleteItem": "વસ્તુ કાઢો",
        "item.deleteConfirm": "'%@' કાઢવું છે? આ ક્રિયા પૂર્વવત કરી શકાશે નહીં.",
        "item.itemName": "વસ્તુ નું નામ", "item.editItemTitle": "વસ્તુ સંપાદિત કરો",
        "stockUpdate.qty": "જથ્થો", "stockUpdate.priceOptional": "ભાવ પ્રતિ એકમ (વૈકલ્પિક)",
        "stockUpdate.currentStock": "હાલ સ્ટૉક", "stockUpdate.purchasePrice": "ખરીદ ભાવ",
        "stockUpdate.mrp": "MRP", "stockUpdate.sellingPrice": "વેચ ભાવ",
        "stockUpdate.insufficientStock": "⚠️ અપૂરતો સ્ટૉક. ઉપલબ્ધ",
        "stockUpdate.errorMsg": "અપૂરતો સ્ટૉક. નેગેટિવ ન જઈ શકે.",
        "settings.title": "સેટિંગ", "settings.businessProfile": "ધંધો પ્રોફાઇલ",
        "settings.businessNamePlaceholder": "ધંધાનું નામ",
        "settings.businessAddressPlaceholder": "ધંધાનું સ્થળ",
        "settings.setBusinessName": "ધંધાનું નામ લખો…",
        "settings.setAddress": "સ્થળ લખો…", "settings.addressLabel": "સ્થળ",
        "settings.godowns": "ગોડાઉન", "settings.addGodown": "ગોડાઉન ઉમેરો",
        "settings.support": "સહાય", "settings.appSupport": "એપ્પ સહાય",
        "settings.about": "વિશે", "settings.privacy": "ગોપનીયતા નીતિ",
        "settings.terms": "સેવાની શરતો", "settings.appearance": "દેખાવ",
        "settings.theme": "થીમ", "settings.language": "ભાષા",
        "theme.system": "સિસ્ટમ ડિફૉલ્ટ", "theme.light": "હળવો", "theme.dark": "ઘેરો",
        "lang.en": "English", "lang.hi": "हिन्दी", "lang.mr": "मराठी", "lang.gu": "ગુજરાતી", "lang.pa": "ਪੰਜਾਬੀ",
        "action.save": "સાચવો", "action.edit": "સંપાદિત", "action.cancel": "રદ",
        "action.delete": "કાઢો", "action.ok": "ઠીક",
        "auth.signIn": "Google સાથે સાઇન ઇન", "auth.syncData": "બધા ઉપકરણ પર ડેટા સિંક",
        "auth.signOut": "સાઇન આઉટ", "auth.signOutConfirm": "શું તમે સાઇન આઉટ કરવા માગો છો?",
        "auth.signInTitle": "સાઇન ઇન", "auth.welcomeBack": "પાછા આવ્યા, સ્વાગત!",
        "auth.signInDesc": "ગોડાઉન ડેટા બધા ઉપકરણ પર\nસિંક કરવા સાઇન ઇન કરો",
        "auth.continueWithGoogle": "Google સાથે ચાલુ",
        "auth.dataPrivate": "તમારો ધંધો ડેટા ખાનગી અને સુરક્ષિત",
        "auth.error": "ભૂલ",
        "cat.addCategory": "શ્રેણી ઉમેરો", "cat.categoryDetails": "શ્રેણી વિગત",
        "cat.categoryNamePlaceholder": "શ્રેણી નું નામ",
        "myBusiness": "મારો ધંધો",
        "noDataAvailable": "આ રિપોર્ટ માટે ડેટા ઉપલબ્ધ નથી.",
        "noLowStock": "ઓછા સ્ટૉકની વસ્તુઓ નથી.",
        "report.selectDate": "તારીખ પસંદ કરો", "report.selectMonth": "મહિનો પસંદ કરો", "report.selectYear": "વર્ષ પસંદ કરો",
        "item.godownLabel": "ગોડાઉન", "item.noTransactions": "હજુ સુધી કોઈ વ્યવહાર નહીં",
        "item.lowStockThreshold": "ઓછા સ્ટૉક ચેતવણી",
        "item.lowStockThresholdHint": "આ જથ્થા સુધી પહોંચ્યે સૂચના (ડિફૉલ્ટ: ઉઘાડ સ્ટૉકના 20%)",
        "item.lowStockAlert": "ઓછા સ્ટૉક ચેતવણી",
        "item.lowStockRemaining": "બાકી — સ્ટૉક ઓછો!",
        "notifications.title": "સૂચનાઓ", "notifications.empty": "હજુ સુધી કોઈ સૂચના નહીં",
        "notifications.done": "થઈ ગયું", "notifications.clearAll": "બધું ખાલી",
        "report.productAnalysis": "ઉત્પાદ વિશ્લેષણ",
        "analysis.selectItem": "વસ્તુ પસંદ કરો", "analysis.noData": "વિશ્લેષણ જોવા વસ્તુ પસંદ કરો",
        "analysis.quantity": "જથ્થો", "analysis.value": "મૂલ્ય (₹)",
    ],
    "pa": [
        "tab.home": "ਹੋਮ", "tab.stock": "ਸਟਾਕ", "tab.items": "ਵਸਤਾਂ",
        "tab.transactions": "ਲੈਣ-ਦੇਣ", "tab.settings": "ਸੈਟਿੰਗ",
        "home.tagline": "ਤੁਹਾਡਾ ਗੋਦਾਮ, ਤੁਹਾਡੀ ਮੁੱਠੀ ਵਿੱਚ", "home.whyTitle": "GodownPe ਕਿਉਂ?",
        "feature.liveTracking": "ਲਾਈਵ ਸਟਾਕ ਟਰੈਕਿੰਗ",
        "feature.liveTrackingDesc": "ਬਿਨਾ ਦੇਰੀ ਰੀਅਲ-ਟਾਈਮ ਅੱਪਡੇਟ",
        "feature.multiLocation": "ਕਈ ਥਾਵਾਂ",
        "feature.multiLocationDesc": "ਇੱਕ ਜਗ੍ਹਾ ਤੋਂ ਸਾਰੀਆਂ ਦੁਕਾਨਾਂ ਸੰਭਾਲੋ",
        "feature.reports": "ਤੁਰੰਤ ਰਿਪੋਰਟ",
        "feature.reportsDesc": "ਸਕਿੰਟਾਂ ਵਿੱਚ ਪ੍ਰੋਫ਼ੈਸ਼ਨਲ PDF ਬਣਾਓ",
        "feature.history": "ਪੂਰਾ ਇਤਿਹਾਸ",
        "feature.historyDesc": "ਹਰ ਲੈਣ-ਦੇਣ ਆਪੇ ਟਰੈਕ ਹੁੰਦਾ",
        "feature.secure": "ਸੁਰੱਖਿਅਤ ਤੇ ਨਿੱਜੀ", "feature.secureDesc": "Google ਡੇਟਾ ਸੁਰੱਖਿਆ",
        "feature.profit": "ਮੁਨਾਫ਼ਾ ਟਰੈਕਿੰਗ", "feature.profitDesc": "ਆਪਣਾ ਮਾਰਜਿਨ ਤੇ ਮੁਨਾਫ਼ਾ ਸਾਫ਼ ਦੇਖੋ",
        "dash.totalProfit": "ਕੁੱਲ ਮੁਨਾਫ਼ਾ", "dash.totalPurchase": "ਕੁੱਲ ਖਰੀਦ",
        "dash.totalSales": "ਕੁੱਲ ਵਿਕਰੀ", "dash.reportsLink": "ਰਿਪੋਰਟ →",
        "dash.summaryLink": "ਵਿਸਤ੍ਰਿਤ ਸਾਰਾਂਸ਼ →", "dash.searchItems": "ਵਸਤਾਂ ਲੱਭੋ",
        "dash.allGodowns": "ਸਾਰੇ ਗੋਦਾਮ", "dash.items": "ਵਸਤਾਂ",
        "period.daily": "ਰੋਜ਼ਾਨਾ", "period.weekly": "ਹਫ਼ਤਾਵਾਰ", "period.monthly": "ਮਹੀਨਾਵਾਰ", "period.yearly": "ਸਾਲਾਨਾ",
        "stock.totalStockIn": "ਕੁੱਲ ਸਟਾਕ ਇਨ", "stock.openingStock": "ਸ਼ੁਰੂਆਤੀ ਸਟਾਕ",
        "stock.totalStockOut": "ਕੁੱਲ ਸਟਾਕ ਆਉਟ", "stock.remainingStock": "ਬਾਕੀ ਸਟਾਕ",
        "stock.updatedRecently": "ਹਾਲ ਹੀ ਵਿੱਚ ਅੱਪਡੇਟ", "stock.btnIn": "ਇਨ", "stock.btnOut": "ਆਉਟ",
        "txn.title": "ਲੈਣ-ਦੇਣ", "txn.search": "ਲੈਣ-ਦੇਣ ਲੱਭੋ",
        "txn.units": "ਇਕਾਈਆਂ", "txn.profit": "ਮੁਨਾਫ਼ਾ",
        "report.title": "ਰਿਪੋਰਟ", "report.dailySales": "ਰੋਜ਼ਾਨਾ ਵਿਕਰੀ",
        "report.monthlySales": "ਮਹੀਨਾਵਾਰ ਵਿਕਰੀ", "report.yearlySales": "ਸਾਲਾਨਾ ਵਿਕਰੀ",
        "report.stockSummary": "ਸਟਾਕ ਸਾਰਾਂਸ਼", "report.lowStock": "ਘੱਟ ਸਟਾਕ ਵਸਤਾਂ",
        "report.profitLoss": "ਮੁਨਾਫ਼ਾ & ਨੁਕਸਾਨ", "report.salesReports": "ਵਿਕਰੀ ਰਿਪੋਰਟ",
        "report.stockReports": "ਸਟਾਕ ਰਿਪੋਰਟ", "report.financialReports": "ਵਿੱਤੀ ਰਿਪੋਰਟ",
        "report.allGodowns": "ਸਾਰੇ ਗੋਦਾਮ", "report.exportPDF": "PDF ਨਿਰਯਾਤ",
        "report.totalTransactions": "ਕੁੱਲ ਲੈਣ-ਦੇਣ", "report.totalSalesAmount": "ਕੁੱਲ ਵਿਕਰੀ ਰਕਮ",
        "report.outOfStock": "ਸਟਾਕ ਖਤਮ",
        "pdf.item": "ਵਸਤੂ", "pdf.qty": "ਮਾਤਰਾ", "pdf.unit": "ਇਕਾਈ", "pdf.pricePerUnit": "ਕੀਮਤ/ਇਕਾਈ",
        "pdf.amount": "ਰਕਮ", "pdf.total": "ਕੁੱਲ", "pdf.opening": "ਸ਼ੁਰੂਆਤੀ",
        "pdf.currStock": "ਮੌਜੂਦਾ.ਸਟਾਕ", "pdf.purchaseVal": "ਖਰੀਦ ₹", "pdf.value": "ਮੁੱਲ ₹",
        "pdf.currentStock": "ਮੌਜੂਦਾ ਸਟਾਕ", "pdf.sellPrice": "ਵਿਕਰੀ ਕੀਮਤ",
        "pdf.purchase": "ਖਰੀਦ", "pdf.profit": "ਮੁਨਾਫ਼ਾ", "pdf.date": "ਤਾਰੀਖ਼",
        "pdf.allGodowns": "ਸਾਰੇ ਗੋਦਾਮ", "pdf.summary": "ਸਾਰਾਂਸ਼",
        "summary.title": "ਵਿਸਤ੍ਰਿਤ ਸਾਰਾਂਸ਼", "summary.allGodowns": "ਸਾਰਾਂਸ਼ (ਸਾਰੇ ਗੋਦਾਮ)",
        "summary.recentTxns": "ਤਾਜ਼ੀਆਂ ਲੈਣ-ਦੇਣ (ਸਾਰੇ ਗੋਦਾਮ)",
        "summary.totalItems": "ਕੁੱਲ ਵਸਤਾਂ", "summary.totalStockValue": "ਕੁੱਲ ਸਟਾਕ ਮੁੱਲ",
        "summary.totalPurchase": "ਕੁੱਲ ਖਰੀਦ", "summary.totalSales": "ਕੁੱਲ ਵਿਕਰੀ",
        "summary.netProfit": "ਸ਼ੁੱਧ ਮੁਨਾਫ਼ਾ",
        "items.title": "ਵਸਤਾਂ", "items.allItems": "ਸਾਰੀਆਂ ਵਸਤਾਂ", "items.searchItems": "ਵਸਤਾਂ ਲੱਭੋ",
        "items.stockIn": "ਸਟਾਕ ਇਨ", "items.stockOut": "ਸਟਾਕ ਆਉਟ",
        "item.addItem": "ਵਸਤੂ ਜੋੜੋ", "item.itemDetails": "ਵਸਤੂ ਵੇਰਵਾ",
        "item.itemNamePlaceholder": "ਵਸਤੂ ਦਾ ਨਾਮ *", "item.noGodowns": "ਕੋਈ ਗੋਦਾਮ ਉਪਲਬਧ ਨਹੀਂ।",
        "item.godownCategory": "ਗੋਦਾਮ (ਸ਼੍ਰੇਣੀ)", "item.godownHeader": "ਗੋਦਾਮ / ਸ਼੍ਰੇਣੀ",
        "item.pricing": "ਕੀਮਤ ਨਿਰਧਾਰਣ", "item.purchasePrice": "ਖਰੀਦ ਕੀਮਤ",
        "item.mrp": "MRP (ਅਧਿਕਤਮ ਪਰਚੂਨ ਕੀਮਤ)", "item.priceUnit": "ਕੀਮਤ ਇਕਾਈ",
        "item.stock": "ਸਟਾਕ", "item.openingStock": "ਸ਼ੁਰੂਆਤੀ ਸਟਾਕ *",
        "item.info": "ਵਸਤੂ ਜਾਣਕਾਰੀ", "item.name": "ਨਾਮ",
        "item.purchasePriceLabel": "ਖਰੀਦ ਕੀਮਤ", "item.mrpLabel": "MRP",
        "item.sellingPrice": "ਵਿਕਰੀ ਕੀਮਤ", "item.priceUnitLabel": "ਕੀਮਤ ਇਕਾਈ",
        "item.openingStockLabel": "ਸ਼ੁਰੂਆਤੀ ਸਟਾਕ", "item.currentStockLabel": "ਮੌਜੂਦਾ ਸਟਾਕ",
        "item.stockMovements": "ਸਟਾਕ ਬਦਲਾਅ", "item.totalStockIn": "ਕੁੱਲ ਸਟਾਕ ਇਨ",
        "item.totalStockOut": "ਕੁੱਲ ਸਟਾਕ ਆਉਟ", "item.stockInLabel": "ਸਟਾਕ ਇਨ",
        "item.stockOutLabel": "ਸਟਾਕ ਆਉਟ", "item.editItem": "ਵਸਤੂ ਸੋਧੋ",
        "item.deleteItem": "ਵਸਤੂ ਹਟਾਓ",
        "item.deleteConfirm": "'%@' ਹਟਾਉਣਾ ਹੈ? ਇਹ ਕਿਰਿਆ ਵਾਪਸ ਨਹੀਂ ਹੋ ਸਕਦੀ।",
        "item.itemName": "ਵਸਤੂ ਦਾ ਨਾਮ", "item.editItemTitle": "ਵਸਤੂ ਸੋਧੋ",
        "stockUpdate.qty": "ਮਾਤਰਾ", "stockUpdate.priceOptional": "ਕੀਮਤ ਪ੍ਰਤੀ ਇਕਾਈ (ਵਿਕਲਪਿਕ)",
        "stockUpdate.currentStock": "ਮੌਜੂਦਾ ਸਟਾਕ", "stockUpdate.purchasePrice": "ਖਰੀਦ ਕੀਮਤ",
        "stockUpdate.mrp": "MRP", "stockUpdate.sellingPrice": "ਵਿਕਰੀ ਕੀਮਤ",
        "stockUpdate.insufficientStock": "⚠️ ਨਾਕਾਫ਼ੀ ਸਟਾਕ। ਉਪਲਬਧ",
        "stockUpdate.errorMsg": "ਨਾਕਾਫ਼ੀ ਸਟਾਕ। ਨੈਗੇਟਿਵ ਨਹੀਂ ਜਾ ਸਕਦਾ।",
        "settings.title": "ਸੈਟਿੰਗ", "settings.businessProfile": "ਕਾਰੋਬਾਰ ਪ੍ਰੋਫਾਈਲ",
        "settings.businessNamePlaceholder": "ਕਾਰੋਬਾਰ ਦਾ ਨਾਮ",
        "settings.businessAddressPlaceholder": "ਕਾਰੋਬਾਰ ਦਾ ਪਤਾ",
        "settings.setBusinessName": "ਕਾਰੋਬਾਰ ਦਾ ਨਾਮ ਲਿਖੋ…",
        "settings.setAddress": "ਪਤਾ ਲਿਖੋ…", "settings.addressLabel": "ਪਤਾ",
        "settings.godowns": "ਗੋਦਾਮ", "settings.addGodown": "ਗੋਦਾਮ ਜੋੜੋ",
        "settings.support": "ਸਹਾਇਤਾ", "settings.appSupport": "ਐਪ ਸਹਾਇਤਾ",
        "settings.about": "ਬਾਰੇ", "settings.privacy": "ਗੋਪਨੀਯਤਾ ਨੀਤੀ",
        "settings.terms": "ਸੇਵਾ ਸ਼ਰਤਾਂ", "settings.appearance": "ਦਿੱਖ",
        "settings.theme": "ਥੀਮ", "settings.language": "ਭਾਸ਼ਾ",
        "theme.system": "ਸਿਸਟਮ ਡਿਫ਼ੌਲਟ", "theme.light": "ਹਲਕਾ", "theme.dark": "ਗੂੜ੍ਹਾ",
        "lang.en": "English", "lang.hi": "हिन्दी", "lang.mr": "मराठी", "lang.gu": "ગુજરાતી", "lang.pa": "ਪੰਜਾਬੀ",
        "action.save": "ਸੇਵ ਕਰੋ", "action.edit": "ਸੋਧੋ", "action.cancel": "ਰੱਦ",
        "action.delete": "ਹਟਾਓ", "action.ok": "ਠੀਕ",
        "auth.signIn": "Google ਨਾਲ ਸਾਈਨ ਇਨ", "auth.syncData": "ਸਾਰੇ ਡਿਵਾਈਸ ਤੇ ਡੇਟਾ ਸਿੰਕ",
        "auth.signOut": "ਸਾਈਨ ਆਉਟ", "auth.signOutConfirm": "ਕੀ ਤੁਸੀਂ ਸਾਈਨ ਆਉਟ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?",
        "auth.signInTitle": "ਸਾਈਨ ਇਨ", "auth.welcomeBack": "ਵਾਪਸ ਆਏ, ਜੀ ਆਇਆਂ!",
        "auth.signInDesc": "ਗੋਦਾਮ ਡੇਟਾ ਨੂੰ ਸਾਰੇ ਡਿਵਾਈਸ ਤੇ\nਸਿੰਕ ਕਰਨ ਲਈ ਸਾਈਨ ਇਨ ਕਰੋ",
        "auth.continueWithGoogle": "Google ਨਾਲ ਜਾਰੀ ਰੱਖੋ",
        "auth.dataPrivate": "ਤੁਹਾਡਾ ਕਾਰੋਬਾਰ ਡੇਟਾ ਨਿੱਜੀ ਤੇ ਸੁਰੱਖਿਅਤ",
        "auth.error": "ਗਲਤੀ",
        "cat.addCategory": "ਸ਼੍ਰੇਣੀ ਜੋੜੋ", "cat.categoryDetails": "ਸ਼੍ਰੇਣੀ ਵੇਰਵਾ",
        "cat.categoryNamePlaceholder": "ਸ਼੍ਰੇਣੀ ਦਾ ਨਾਮ",
        "myBusiness": "ਮੇਰਾ ਕਾਰੋਬਾਰ",
        "noDataAvailable": "ਇਸ ਰਿਪੋਰਟ ਲਈ ਡੇਟਾ ਉਪਲਬਧ ਨਹੀਂ।",
        "noLowStock": "ਘੱਟ ਸਟਾਕ ਵਸਤਾਂ ਨਹੀਂ।",
        "report.selectDate": "ਤਾਰੀਖ਼ ਚੁਣੋ", "report.selectMonth": "ਮਹੀਨਾ ਚੁਣੋ", "report.selectYear": "ਸਾਲ ਚੁਣੋ",
        "item.godownLabel": "ਗੋਦਾਮ", "item.noTransactions": "ਅਜੇ ਕੋਈ ਲੈਣ-ਦੇਣ ਨਹੀਂ",
        "item.lowStockThreshold": "ਘੱਟ ਸਟਾਕ ਚੇਤਾਵਨੀ",
        "item.lowStockThresholdHint": "ਇਸ ਮਾਤਰਾ ਤੱਕ ਪਹੁੰਚਣ ਤੇ ਸੂਚਨਾ (ਡਿਫ਼ੌਲਟ: ਸ਼ੁਰੂਆਤੀ ਸਟਾਕ ਦਾ 20%)",
        "item.lowStockAlert": "ਘੱਟ ਸਟਾਕ ਚੇਤਾਵਨੀ",
        "item.lowStockRemaining": "ਬਾਕੀ — ਸਟਾਕ ਘੱਟ!",
        "notifications.title": "ਸੂਚਨਾਵਾਂ", "notifications.empty": "ਅਜੇ ਕੋਈ ਸੂਚਨਾ ਨਹੀਂ",
        "notifications.done": "ਹੋ ਗਿਆ", "notifications.clearAll": "ਸਭ ਸਾਫ਼",
        "report.productAnalysis": "ਉਤਪਾਦ ਵਿਸ਼ਲੇਸ਼ਣ",
        "analysis.selectItem": "ਵਸਤੂ ਚੁਣੋ", "analysis.noData": "ਵਿਸ਼ਲੇਸ਼ਣ ਦੇਖਣ ਲਈ ਵਸਤੂ ਚੁਣੋ",
        "analysis.quantity": "ਮਾਤਰਾ", "analysis.value": "ਮੁੱਲ (₹)",
    ]
]

// MARK: - GodownPe Logo Mark
struct GodownPeLogoMark: View {
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(LinearGradient(
                    colors: [.gpOrange, .gpOrangeDark],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
            Image(systemName: "building.2.fill")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

@main
struct GodownPeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var appSettings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(appSettings)
                .preferredColorScheme(appSettings.colorScheme)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    await authManager.restorePreviousSignIn()
                }
        }
    }
}

// Models.swift
import Foundation

struct UserCategory: Identifiable, Codable {
    var id = UUID()
    var name: String
    var dateCreated: Date
}

struct InventoryItem: Identifiable, Codable {
    var id = UUID()
    var categoryId: UUID
    var name: String
    var purchasePrice: Double?
    var mrp: Double?
    var sellingPrice: Double?
    var priceUnit: String
    var category: String = ""
    var openingStock: Double
    var currentStock: Double
    var dateAdded: Date
    var lowStockThreshold: Double? = nil   // nil = auto (20% of opening stock)

    var effectiveLowStockThreshold: Double {
        lowStockThreshold ?? (openingStock * 0.20)
    }
    var isLowStock: Bool {
        effectiveLowStockThreshold > 0 && currentStock <= effectiveLowStockThreshold
    }
}

struct Transaction: Identifiable, Codable {
    var id = UUID()
    var categoryId: UUID
    var itemId: UUID
    var itemName: String
    var type: TransactionType
    var quantity: Double
    var pricePerUnit: Double?
    var totalAmount: Double
    var profit: Double?
    var date: Date

    enum TransactionType: String, Codable {
        case stockIn = "Stock In"
        case stockOut = "Stock Out"
        case sale = "Sale"
        case purchase = "Purchase"
    }
}

struct PriceUnit {
    static let units = [
        "Bag", "Bora", "Bori", "Bundle", "Carat",
        "cartoon", "CM", "Danda", "Day", "Dibba",
        "Dozen", "Feet", "Gross", "Hour", "Inch",
        "Jar", "jhaal", "Katta", "katti", "KG",
        "KM", "ladi", "Litre", "Meter", "Minute",
        "ML", "MM", "Month", "Pair", "panni",
        "Peepa", "Person", "Piece", "Plate", "Pouch",
        "Pound", "Quintal", "Ratti", "Service", "Sq.Ft",
        "Sq.Inch", "Sq.Meter", "Thaila", "Thaila 25", "Tin",
        "Ton", "Trolley", "Truck", "Work", "Year",
        "15 litre", "30 kg", "50 kg"
    ]
}

enum SortOption: String, CaseIterable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case stockLow = "Stock (Low to High)"
    case stockHigh = "Stock (High to Low)"
    case dateNew = "Date (Newest)"
    case dateOld = "Date (Oldest)"
}

// InventoryViewModel.swift
import Foundation
import Combine
import UIKit

class InventoryViewModel: ObservableObject {
    @Published var items: [InventoryItem] = []
    @Published var transactions: [Transaction] = []
    @Published var categories: [UserCategory] = []
    @Published var currentCategoryId: UUID?
    @Published var businessName: String = ""
    @Published var businessAddress: String = ""
    @Published var isLoading: Bool = false

    private let db = Firestore.firestore()
    private var userId: String = ""
    private var listeners: [ListenerRegistration] = []
    private var initialLoadDone = false

    var currentCategory: UserCategory? {
        guard let id = currentCategoryId else { return categories.first }
        return categories.first(where: { $0.id == id })
    }

    var currentCategoryItems: [InventoryItem] {
        guard let categoryId = currentCategoryId else { return [] }
        return items.filter { $0.categoryId == categoryId }
    }

    var currentCategoryTransactions: [Transaction] {
        guard let categoryId = currentCategoryId else { return [] }
        return transactions.filter { $0.categoryId == categoryId }
    }

    init() {}

    func configure(userId: String) {
        listeners.forEach { $0.remove() }
        listeners = []
        items = []
        transactions = []
        categories = []
        currentCategoryId = nil
        businessName = ""
        businessAddress = ""
        initialLoadDone = false

        guard !userId.isEmpty else { return }
        self.userId = userId
        attachListeners()
    }

    private func userRef() -> DocumentReference {
        db.collection("users").document(userId)
    }

    private func attachListeners() {
        isLoading = true

        let catListener = userRef().collection("businesses")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let snap = snap else { return }
                let decoded: [UserCategory] = snap.documents.compactMap {
                    try? Self.decodeModel(UserCategory.self, from: $0.data())
                }
                DispatchQueue.main.async {
                    self.categories = decoded
                    if !self.initialLoadDone {
                        self.initialLoadDone = true
                        if decoded.isEmpty {
                            let cat = UserCategory(name: "General", dateCreated: Date())
                            self.addCategory(cat)
                            self.addSampleData(for: cat.id)
                        } else if self.currentCategoryId == nil ||
                                  !decoded.contains(where: { $0.id == self.currentCategoryId }) {
                            self.currentCategoryId = decoded.first?.id
                        }
                    }
                    self.isLoading = false
                }
            }
        listeners.append(catListener)

        let itemsListener = userRef().collection("items")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let snap = snap else { return }
                let decoded: [InventoryItem] = snap.documents.compactMap {
                    try? Self.decodeModel(InventoryItem.self, from: $0.data())
                }
                DispatchQueue.main.async { self.items = decoded }
            }
        listeners.append(itemsListener)

        let txnsListener = userRef().collection("transactions")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let snap = snap else { return }
                let decoded: [Transaction] = snap.documents.compactMap {
                    try? Self.decodeModel(Transaction.self, from: $0.data())
                }
                DispatchQueue.main.async { self.transactions = decoded }
            }
        listeners.append(txnsListener)

        let settingsListener = userRef().collection("settings").document("current")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let snap = snap, snap.exists else { return }
                let data = snap.data() ?? [:]
                if let idStr = data["currentCategoryId"] as? String,
                   let id = UUID(uuidString: idStr) {
                    DispatchQueue.main.async { self.currentCategoryId = id }
                }
                if let name = data["businessName"] as? String {
                    DispatchQueue.main.async { self.businessName = name }
                }
                if let addr = data["businessAddress"] as? String {
                    DispatchQueue.main.async { self.businessAddress = addr }
                }
            }
        listeners.append(settingsListener)
    }

    private static func decodeModel<T: Decodable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(type, from: data)
    }

    private func encodeModel<T: Encodable>(_ value: T) -> [String: Any]? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(value),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }

    private func saveSettings() {
        guard !userId.isEmpty else { return }
        var data: [String: Any] = [
            "businessName": businessName,
            "businessAddress": businessAddress
        ]
        if let id = currentCategoryId { data["currentCategoryId"] = id.uuidString }
        userRef().collection("settings").document("current").setData(data, merge: true)
    }

    func updateBusinessName(_ name: String) {
        businessName = name
        saveSettings()
    }

    func updateBusinessAddress(_ address: String) {
        businessAddress = address
        saveSettings()
    }

    var totalPurchase: Double {
        currentCategoryTransactions
            .filter { $0.type == .purchase || $0.type == .stockIn }
            .reduce(0) { $0 + $1.totalAmount }
    }

    var totalSales: Double {
        currentCategoryTransactions
            .filter { $0.type == .sale || $0.type == .stockOut }
            .reduce(0) { $0 + $1.totalAmount }
    }

    var totalProfit: Double {
        totalSales - totalPurchase
    }
    
    var allGodownsTotalPurchase: Double {
        transactions
            .filter { $0.type == .purchase || $0.type == .stockIn }
            .reduce(0) { $0 + $1.totalAmount }
    }

    var allGodownsTotalSales: Double {
        transactions
            .filter { $0.type == .sale || $0.type == .stockOut }
            .reduce(0) { $0 + $1.totalAmount }
    }

    var allGodownsTotalProfit: Double {
        transactions
            .filter { $0.type == .sale || $0.type == .stockOut }
            .reduce(0) { $0 + ($1.profit ?? 0) }
    }

    func sortedItems(_ items: [InventoryItem], by sortOption: SortOption) -> [InventoryItem] {
        switch sortOption {
        case .nameAsc: return items.sorted { $0.name < $1.name }
        case .nameDesc: return items.sorted { $0.name > $1.name }
        case .stockLow: return items.sorted { $0.currentStock < $1.currentStock }
        case .stockHigh: return items.sorted { $0.currentStock > $1.currentStock }
        case .dateNew: return items.sorted { $0.dateAdded > $1.dateAdded }
        case .dateOld: return items.sorted { $0.dateAdded < $1.dateAdded }
        }
    }

    func generateStructuredPDF(
        title: String,
        godownName: String,
        headers: [String],
        rows: [[String]],
        summary: [(String, String)]
    ) -> URL? {
        let pageW: CGFloat = 595.28
        let pageH: CGFloat = 841.89
        let mg: CGFloat = 36.0
        let tableW = pageW - 2.0 * mg
        let colCount = max(1, headers.count)

        var colWidths: [CGFloat] = Array(repeating: tableW / CGFloat(colCount), count: colCount)
        if colCount > 1 {
            colWidths[0] = tableW * 0.28
            let rest = (tableW - colWidths[0]) / CGFloat(colCount - 1)
            for i in 1..<colCount { colWidths[i] = rest }
        }

        let orange = UIColor(red: 1.0, green: 0.55, blue: 0.11, alpha: 1.0)
        let altRow = UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
        let border = UIColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1.0)
        let rowH: CGFloat = 18.0
        let hdrH: CGFloat = 22.0

        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        let genTime = df.string(from: Date())

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle: title] as [String: Any]
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH),
            format: format
        )

        let data = renderer.pdfData { ctx in

            func newPage() {
                ctx.beginPage()
                orange.setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: pageW, height: 28.0))
                let a: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10.0), .foregroundColor: UIColor.white]
                "GodownPe — \(title) (continued)".draw(at: CGPoint(x: mg, y: 7.0), withAttributes: a)
            }

            func drawRow(y: CGFloat, cells: [String], isHdr: Bool, isAlt: Bool) {
                let rh = isHdr ? hdrH : rowH
                if isHdr { orange.setFill(); UIRectFill(CGRect(x: mg, y: y, width: tableW, height: rh)) }
                else if isAlt { altRow.setFill(); UIRectFill(CGRect(x: mg, y: y, width: tableW, height: rh)) }
                var cx = mg
                for i in 0..<colCount {
                    let w = colWidths[i]
                    border.setStroke()
                    let p = UIBezierPath(rect: CGRect(x: cx, y: y, width: w, height: rh))
                    p.lineWidth = 0.5; p.stroke()
                    let text = i < cells.count ? cells[i] : ""
                    let attrs: [NSAttributedString.Key: Any] = isHdr
                        ? [.font: UIFont.boldSystemFont(ofSize: 8.0), .foregroundColor: UIColor.white]
                        : [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.black]
                    text.draw(in: CGRect(x: cx + 4.0, y: y + (rh - 10.0) / 2.0, width: w - 8.0, height: rh), withAttributes: attrs)
                    cx += w
                }
            }

            // ---- Page 1 ----
            ctx.beginPage()
            var y: CGFloat = 0.0

            // Orange header
            orange.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: pageW, height: 62.0))
            "GodownPe".draw(at: CGPoint(x: mg, y: 12.0), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 22.0), .foregroundColor: UIColor.white])
            "Inventory Management".draw(at: CGPoint(x: mg, y: 38.0), withAttributes: [.font: UIFont.systemFont(ofSize: 9.0), .foregroundColor: UIColor.white.withAlphaComponent(0.85)])
            let gs = genTime.size(withAttributes: [.font: UIFont.systemFont(ofSize: 8.0), .foregroundColor: UIColor.white])
            genTime.draw(at: CGPoint(x: pageW - mg - gs.width, y: 26.0), withAttributes: [.font: UIFont.systemFont(ofSize: 8.0), .foregroundColor: UIColor.white.withAlphaComponent(0.9)])
            y = 76.0

            // Business name
            let bizName = businessName.isEmpty ? t("myBusiness") : businessName
            bizName.draw(at: CGPoint(x: mg, y: y), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 13.0), .foregroundColor: UIColor.black])
            y += 18.0
            if !businessAddress.isEmpty {
                businessAddress.draw(at: CGPoint(x: mg, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 9.5), .foregroundColor: UIColor.darkGray])
                y += 14.0
            }

            // Report title + godown
            title.draw(at: CGPoint(x: mg, y: y), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 15.0), .foregroundColor: orange])
            let gLabel = godownName.isEmpty ? t("pdf.allGodowns") : godownName
            let gSize = gLabel.size(withAttributes: [.font: UIFont.systemFont(ofSize: 9.0), .foregroundColor: UIColor.darkGray])
            gLabel.draw(at: CGPoint(x: pageW - mg - gSize.width, y: y + 3.0), withAttributes: [.font: UIFont.systemFont(ofSize: 9.0), .foregroundColor: UIColor.darkGray])
            y += 22.0

            // Divider
            orange.setStroke()
            let dp = UIBezierPath(); dp.move(to: CGPoint(x: mg, y: y)); dp.addLine(to: CGPoint(x: pageW - mg, y: y)); dp.lineWidth = 1.5; dp.stroke()
            y += 10.0

            // Table header
            if !headers.isEmpty {
                if y + hdrH > pageH - mg - 40.0 { newPage(); y = 38.0 }
                drawRow(y: y, cells: headers, isHdr: true, isAlt: false)
                y += hdrH
            }

            // Data rows
            if rows.isEmpty {
                "No data available for this report.".draw(at: CGPoint(x: mg + 8.0, y: y + 8.0),
                    withAttributes: [.font: UIFont.italicSystemFont(ofSize: 9.0), .foregroundColor: UIColor.gray])
                y += 28.0
            } else {
                for (idx, row) in rows.enumerated() {
                    if y + rowH > pageH - mg - 40.0 { newPage(); y = 38.0 }
                    drawRow(y: y, cells: row, isHdr: false, isAlt: idx % 2 == 1)
                    y += rowH
                }
            }

            y += 14.0

            // Summary
            if !summary.isEmpty {
                if y + CGFloat(summary.count) * 18.0 + 28.0 > pageH - mg - 40.0 { newPage(); y = 38.0 }
                t("pdf.summary").draw(at: CGPoint(x: mg, y: y), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 11.0), .foregroundColor: UIColor.black])
                y += 14.0
                UIColor.lightGray.setStroke()
                let sp = UIBezierPath(); sp.move(to: CGPoint(x: mg, y: y)); sp.addLine(to: CGPoint(x: pageW - mg, y: y)); sp.lineWidth = 0.75; sp.stroke()
                y += 7.0
                for (label, value) in summary {
                    label.draw(at: CGPoint(x: mg, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 10.0), .foregroundColor: UIColor.darkGray])
                    let vs = value.size(withAttributes: [.font: UIFont.boldSystemFont(ofSize: 10.0), .foregroundColor: UIColor.black])
                    value.draw(at: CGPoint(x: pageW - mg - vs.width, y: y), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 10.0), .foregroundColor: UIColor.black])
                    y += 16.0
                }
            }

            // Footer
            let fy = pageH - 22.0
            UIColor.lightGray.setStroke()
            let flp = UIBezierPath(); flp.move(to: CGPoint(x: mg, y: fy - 5.0)); flp.addLine(to: CGPoint(x: pageW - mg, y: fy - 5.0)); flp.lineWidth = 0.5; flp.stroke()
            let footerText = "© 2026 GodownPe  •  Generated: \(genTime)"
            let fSize = footerText.size(withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.lightGray])
            footerText.draw(at: CGPoint(x: (pageW - fSize.width) / 2.0, y: fy), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.lightGray])
        }

        let fileName = "\(title.replacingOccurrences(of: " ", with: "_"))_\(Date().formatted(.iso8601.year().month().day())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return url
    }

    func addCategory(_ category: UserCategory) {
        categories.append(category)
        if currentCategoryId == nil {
            currentCategoryId = category.id
            saveSettings()
        }
        guard !userId.isEmpty else { return }
        if let data = encodeModel(category) {
            userRef().collection("businesses").document(category.id.uuidString).setData(data)
        }
    }

    func deleteCategory(_ category: UserCategory) {
        categories.removeAll { $0.id == category.id }
        items.removeAll { $0.categoryId == category.id }
        transactions.removeAll { $0.categoryId == category.id }
        if currentCategoryId == category.id {
            currentCategoryId = categories.first?.id
            saveSettings()
        }
        guard !userId.isEmpty else { return }
        let batch = db.batch()
        batch.deleteDocument(userRef().collection("businesses").document(category.id.uuidString))
        Task {
            if let snap = try? await userRef().collection("items")
                .whereField("categoryId", isEqualTo: category.id.uuidString)
                .getDocuments() {
                snap.documents.forEach { batch.deleteDocument($0.reference) }
            }
            if let snap = try? await userRef().collection("transactions")
                .whereField("categoryId", isEqualTo: category.id.uuidString)
                .getDocuments() {
                snap.documents.forEach { batch.deleteDocument($0.reference) }
            }
            try? await batch.commit()
        }
    }

    func switchCategory(to categoryId: UUID) {
        currentCategoryId = categoryId
        saveSettings()
    }

    func addItem(_ item: InventoryItem) {
        items.append(item)
        guard !userId.isEmpty else { return }
        if let data = encodeModel(item) {
            userRef().collection("items").document(item.id.uuidString).setData(data)
        }
    }

    func updateItem(_ item: InventoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
        guard !userId.isEmpty else { return }
        if let data = encodeModel(item) {
            userRef().collection("items").document(item.id.uuidString).setData(data)
        }
    }

    func deleteItem(_ item: InventoryItem) {
        items.removeAll { $0.id == item.id }
        transactions.removeAll { $0.itemId == item.id }
        guard !userId.isEmpty else { return }
        let batch = db.batch()
        batch.deleteDocument(userRef().collection("items").document(item.id.uuidString))
        Task {
            if let snap = try? await userRef().collection("transactions")
                .whereField("itemId", isEqualTo: item.id.uuidString)
                .getDocuments() {
                snap.documents.forEach { batch.deleteDocument($0.reference) }
            }
            try? await batch.commit()
        }
    }

    func addTransaction(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
        guard !userId.isEmpty else { return }
        if let data = encodeModel(transaction) {
            userRef().collection("transactions").document(transaction.id.uuidString).setData(data)
        }
    }

    func stockIn(for item: InventoryItem, quantity: Double, pricePerUnit: Double?) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].currentStock += quantity
            let totalAmount = (pricePerUnit ?? 0) * quantity
            let transaction = Transaction(
                categoryId: item.categoryId,
                itemId: item.id,
                itemName: item.name,
                type: .stockIn,
                quantity: quantity,
                pricePerUnit: pricePerUnit,
                totalAmount: totalAmount,
                date: Date()
            )
            addTransaction(transaction)
            if !items[index].isLowStock {
                cancelLowStockReminders(for: items[index])
            }
            guard !userId.isEmpty else { return }
            if let data = encodeModel(items[index]) {
                userRef().collection("items").document(item.id.uuidString).setData(data)
            }
        }
    }

    func stockOut(for item: InventoryItem, quantity: Double, pricePerUnit: Double?) -> Bool {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            if items[index].currentStock - quantity < 0 { return false }
            items[index].currentStock -= quantity
            let sellPrice = pricePerUnit ?? item.sellingPrice ?? 0
            let totalAmount = sellPrice * quantity
            let hasPrice = item.purchasePrice != nil || item.sellingPrice != nil || pricePerUnit != nil
            let profit: Double? = hasPrice ? (sellPrice - (item.purchasePrice ?? 0)) * quantity : nil
            let transaction = Transaction(
                categoryId: item.categoryId,
                itemId: item.id,
                itemName: item.name,
                type: .stockOut,
                quantity: quantity,
                pricePerUnit: pricePerUnit,
                totalAmount: totalAmount,
                profit: profit,
                date: Date()
            )
            addTransaction(transaction)
            if items[index].isLowStock {
                sendLowStockNotification(for: items[index])
            }
            guard !userId.isEmpty else { return true }
            if let data = encodeModel(items[index]) {
                userRef().collection("items").document(item.id.uuidString).setData(data)
            }
            return true
        }
        return false
    }

    func sendLowStockNotification(for item: InventoryItem) {
        let title = t("item.lowStockAlert")
        let body = "\(item.name): \(String(format: "%.1f", item.currentStock)) \(item.priceUnit) \(t("item.lowStockRemaining"))"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let center = UNUserNotificationCenter.current()

        // Schedule daily reminder at 10:00 AM
        var components10 = DateComponents()
        components10.hour = 10
        components10.minute = 0
        let trigger10 = UNCalendarNotificationTrigger(dateMatching: components10, repeats: true)
        center.add(UNNotificationRequest(
            identifier: "lowstock-10am-\(item.id.uuidString)",
            content: content, trigger: trigger10), withCompletionHandler: nil)

        // Schedule daily reminder at 5:00 PM
        var components17 = DateComponents()
        components17.hour = 17
        components17.minute = 0
        let trigger17 = UNCalendarNotificationTrigger(dateMatching: components17, repeats: true)
        center.add(UNNotificationRequest(
            identifier: "lowstock-5pm-\(item.id.uuidString)",
            content: content, trigger: trigger17), withCompletionHandler: nil)

        DispatchQueue.main.async {
            AppSettings.shared.addNotification(title: title, body: body)
        }
    }

    func cancelLowStockReminders(for item: InventoryItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "lowstock-10am-\(item.id.uuidString)",
            "lowstock-5pm-\(item.id.uuidString)"
        ])
    }

    func getStockIn(for item: InventoryItem) -> Double {
        currentCategoryTransactions
            .filter { $0.itemId == item.id && ($0.type == .stockIn || $0.type == .purchase) }
            .reduce(0) { $0 + $1.quantity }
    }

    func getStockOut(for item: InventoryItem) -> Double {
        currentCategoryTransactions
            .filter { $0.itemId == item.id && ($0.type == .stockOut || $0.type == .sale) }
            .reduce(0) { $0 + $1.quantity }
    }

    func saveData() {}

    private func addSampleData(for categoryId: UUID) {
        let biri = InventoryItem(
            categoryId: categoryId,
            name: "36 no biri, D1",
            purchasePrice: 450,
            mrp: 500,
            sellingPrice: 480,
            priceUnit: "cartoon",
            openingStock: 2.0,
            currentStock: 2.0,
            dateAdded: Date()
        )
        let sabun = InventoryItem(
            categoryId: categoryId,
            name: "5 Bhai Sabun",
            purchasePrice: 80,
            mrp: 100,
            sellingPrice: 95,
            priceUnit: "Bundle",
            openingStock: 0,
            currentStock: 0,
            dateAdded: Date()
        )
        addItem(biri)
        addItem(sabun)
    }
}

// ContentView.swift
import SwiftUI

// MARK: - Notifications UI

private struct NotificationRowView: View {
    let record: NotificationRecord
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if !record.isRead {
                        Circle().fill(Color.gpOrange).frame(width: 8, height: 8)
                    }
                }
                Text(record.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(record.date, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NotificationsView: View {
    @ObservedObject var appSettings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Group {
                if appSettings.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 52))
                            .foregroundColor(.secondary)
                        Text(t("notifications.empty"))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
                } else {
                    List {
                        ForEach(appSettings.notifications.indices, id: \.self) { index in
                            NotificationRowView(record: appSettings.notifications[index])
                        }
                        .onDelete { indices in
                            appSettings.notifications.remove(atOffsets: indices)
                            appSettings.savePublicNotifications()
                        }
                    }
                }
            }
            .navigationTitle(t("notifications.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("notifications.done")) {
                        appSettings.markAllRead()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !appSettings.notifications.isEmpty {
                        Button(t("notifications.clearAll")) {
                            appSettings.notifications.removeAll()
                            appSettings.savePublicNotifications()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .onAppear { appSettings.markAllRead() }
        }
    }
}

struct BellToolbarButton: View {
    @ObservedObject var appSettings = AppSettings.shared
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                if appSettings.unreadCount > 0 {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var appSettings: AppSettings
    @State private var selectedTab = 1

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(t("tab.home"), systemImage: "house.fill")
                }
                .tag(0)

            DashboardView(viewModel: viewModel, selectedTab: $selectedTab)
                .tabItem {
                    Label(t("tab.stock"), systemImage: "arrow.left.arrow.right")
                }
                .tag(1)

            InventoryListView(viewModel: viewModel)
                .tabItem {
                    Label(t("tab.items"), systemImage: "square.grid.2x2.fill")
                }
                .tag(2)

            TransactionsView(viewModel: viewModel)
                .tabItem {
                    Label(t("tab.transactions"), systemImage: "list.bullet.rectangle")
                }
                .tag(3)

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label(t("tab.settings"), systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .id(appSettings.language)
        .tint(.gpOrange)
        .onAppear {
            viewModel.configure(userId: authManager.isSignedIn ? authManager.userId : "")
        }
        .onChange(of: authManager.isSignedIn) { isSignedIn in
            viewModel.configure(userId: isSignedIn ? authManager.userId : "")
        }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {

                    // Hero banner
                    ZStack {
                        LinearGradient(
                            colors: [.gpOrange, .gpOrangeDark],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea(edges: .top)

                        VStack(spacing: 14) {
                            GodownPeLogoMark(size: 72)

                            VStack(spacing: 6) {
                                HStack(spacing: 0) {
                                    Text("Godown")
                                        .font(.system(size: 34, weight: .black))
                                        .foregroundColor(.white)
                                    Text("Pe")
                                        .font(.system(size: 34, weight: .black))
                                        .foregroundColor(.white.opacity(0.75))
                                }

                                Text(t("home.tagline"))
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.vertical, 44)
                        .padding(.horizontal)
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 28,
                            bottomTrailingRadius: 28,
                            topTrailingRadius: 0
                        )
                    )

                    VStack(spacing: 24) {

                        // Feature cards
                        VStack(alignment: .leading, spacing: 16) {
                            Text(t("home.whyTitle"))
                                .font(.title2.bold())
                                .padding(.horizontal)
                                .padding(.top, 8)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 16) {
                                FeatureGridCard(icon: "chart.line.uptrend.xyaxis", title: t("feature.liveTracking"),
                                    description: t("feature.liveTrackingDesc"))
                                FeatureGridCard(icon: "building.2.fill", title: t("feature.multiLocation"),
                                    description: t("feature.multiLocationDesc"))
                                FeatureGridCard(icon: "doc.text.fill", title: t("feature.reports"),
                                    description: t("feature.reportsDesc"))
                                FeatureGridCard(icon: "arrow.triangle.2.circlepath", title: t("feature.history"),
                                    description: t("feature.historyDesc"))
                                FeatureGridCard(icon: "lock.shield.fill", title: t("feature.secure"),
                                    description: t("feature.secureDesc"))
                                FeatureGridCard(icon: "indianrupeesign.circle.fill", title: t("feature.profit"),
                                    description: t("feature.profitDesc"))
                            }
                            .padding(.horizontal)
                        }


                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.gpOrange)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct FeatureGridCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.gpOrange)
                .frame(width: 44, height: 44)
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.08), radius: 4, y: 2)
        )
    }
}

struct QuickStartStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.gpOrange)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @Binding var selectedTab: Int
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedDate = Date()
    @State private var selectedPeriod = "Daily"
    @State private var selectedCategoryId: UUID? = nil
    @State private var searchText = ""
    @State private var sortOption: SortOption = .nameAsc
    @State private var showingNotifications = false
    @State private var showingAddItem = false
    @State private var showingLoginSheet = false

    let periods = ["Daily", "Weekly", "Monthly", "Yearly"]
    func localizedPeriod(_ p: String) -> String { t("period.\(p.lowercased())") }

    var selectedItems: [InventoryItem] {
        var items: [InventoryItem]
        if let id = selectedCategoryId {
            items = viewModel.items.filter { $0.categoryId == id }
        } else {
            items = viewModel.items
        }
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return viewModel.sortedItems(items, by: sortOption)
    }

    var selectedTransactions: [Transaction] {
        if let id = selectedCategoryId {
            return viewModel.transactions.filter { $0.categoryId == id }
        }
        return viewModel.transactions
    }

    var dateFilteredTransactions: [Transaction] {
        let cal = Calendar.current
        return selectedTransactions.filter { txn in
            switch selectedPeriod {
            case "Daily":
                return cal.isDate(txn.date, inSameDayAs: selectedDate)
            case "Weekly":
                guard let week = cal.dateInterval(of: .weekOfYear, for: selectedDate) else { return false }
                return week.contains(txn.date)
            case "Monthly":
                return cal.isDate(txn.date, equalTo: selectedDate, toGranularity: .month)
            case "Yearly":
                return cal.isDate(txn.date, equalTo: selectedDate, toGranularity: .year)
            default:
                return true
            }
        }
    }

    var totalPurchaseFiltered: Double {
        dateFilteredTransactions
            .filter { $0.type == .purchase || $0.type == .stockIn }
            .reduce(0) { $0 + $1.totalAmount }
    }

    var totalSalesFiltered: Double {
        dateFilteredTransactions
            .filter { $0.type == .sale || $0.type == .stockOut }
            .reduce(0) { $0 + $1.totalAmount }
    }

    var profitFiltered: Double {
        dateFilteredTransactions
            .filter { $0.type == .sale || $0.type == .stockOut }
            .reduce(0) { $0 + ($1.profit ?? 0) }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(.secondarySystemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Gradient header
                        ZStack {
                            LinearGradient(
                                colors: [.gpOrange, .gpOrangeDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 120)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 28,
                                    bottomTrailingRadius: 28,
                                    topTrailingRadius: 0
                                )
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    HStack(spacing: 10) {
                                        GodownPeLogoMark(size: 36)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(viewModel.businessName.isEmpty ? t("myBusiness") : viewModel.businessName)
                                                .font(.title2.bold())
                                                .foregroundColor(.white)
                                            HStack(spacing: 0) {
                                                Text("Godown").font(.caption).foregroundColor(.white.opacity(0.9))
                                                Text("Pe").font(.caption).foregroundColor(.white.opacity(0.6))
                                            }
                                        }
                                    }
                                    Spacer()
                                    Button(action: { showingNotifications = true }) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(systemName: "bell.fill")
                                                .font(.title3)
                                                .foregroundColor(.white.opacity(0.85))
                                            if AppSettings.shared.unreadCount > 0 {
                                                Circle().fill(.red).frame(width: 8, height: 8).offset(x: 4, y: -4)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                        }

                        VStack(spacing: 12) {
                            // Category dropdown filter
                            Menu {
                                Button(action: { selectedCategoryId = nil }) {
                                    HStack {
                                        Text("\(t("dash.allGodowns")) (\(viewModel.items.count) \(t("dash.items")))")
                                        if selectedCategoryId == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Divider()
                                ForEach(viewModel.categories) { cat in
                                    let count = viewModel.items.filter { $0.categoryId == cat.id }.count
                                    Button(action: { selectedCategoryId = cat.id }) {
                                        HStack {
                                            Text("\(cat.name)  (\(count) \(t("dash.items")))")
                                            if selectedCategoryId == cat.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .foregroundColor(.gpOrange)
                                        .font(.title3)
                                    let label: String = {
                                        if let id = selectedCategoryId,
                                           let cat = viewModel.categories.first(where: { $0.id == id }) {
                                            let count = viewModel.items.filter { $0.categoryId == cat.id }.count
                                            return "\(cat.name)  (\(count) \(t("dash.items")))"
                                        }
                                        return "\(t("dash.allGodowns"))  (\(viewModel.items.count) \(t("dash.items")))"
                                    }()
                                    Text(label)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.07), radius: 4, y: 2)
                            }
                            .padding(.horizontal)

                            // Date & period row
                            HStack {
                                Button(action: {
                                    let comp: Calendar.Component = selectedPeriod == "Weekly" ? .weekOfYear : selectedPeriod == "Monthly" ? .month : selectedPeriod == "Yearly" ? .year : .day
                                    selectedDate = Calendar.current.date(byAdding: comp, value: -1, to: selectedDate) ?? selectedDate
                                }) {
                                    Image(systemName: "chevron.left").foregroundColor(.primary)
                                }
                                Spacer()
                                VStack(spacing: 2) {
                                    Text(selectedDate, style: .date).font(.headline)
                                    if selectedPeriod == "Weekly" {
                                        if let week = Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate) {
                                            Text("\(week.start, style: .date) – \(Calendar.current.date(byAdding: .day, value: -1, to: week.end) ?? week.end, style: .date)")
                                                .font(.caption2).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                                Button(action: {
                                    let comp: Calendar.Component = selectedPeriod == "Weekly" ? .weekOfYear : selectedPeriod == "Monthly" ? .month : selectedPeriod == "Yearly" ? .year : .day
                                    selectedDate = Calendar.current.date(byAdding: comp, value: 1, to: selectedDate) ?? selectedDate
                                }) {
                                    Image(systemName: "chevron.right").foregroundColor(.primary)
                                }
                                Menu {
                                    ForEach(periods, id: \.self) { p in Button(localizedPeriod(p)) { selectedPeriod = p } }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(localizedPeriod(selectedPeriod)).font(.subheadline)
                                        Image(systemName: "chevron.down").font(.caption)
                                    }
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.tertiarySystemFill))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.07), radius: 4, y: 2)
                            .padding(.horizontal)

                            // Summary card
                            VStack(spacing: 10) {
                                HStack {
                                    Text(t("dash.totalProfit"))
                                        .font(.headline)
                                    Spacer()
                                    let profit = profitFiltered
                                    Text("₹ \(String(format: "%.2f", profit))")
                                        .font(.headline)
                                        .foregroundColor(profit >= 0 ? .green : .red)
                                }
                                Divider()
                                HStack {
                                    Text(t("dash.totalPurchase")).foregroundColor(.secondary)
                                    Spacer()
                                    let purchase = selectedCategoryId == nil ? viewModel.allGodownsTotalPurchase : totalPurchaseFiltered
                                    Text("₹ \(String(format: "%.2f", purchase))").foregroundColor(.red)
                                }
                                HStack {
                                    Text(t("dash.totalSales")).foregroundColor(.secondary)
                                    Spacer()
                                    let sales = selectedCategoryId == nil ? viewModel.allGodownsTotalSales : totalSalesFiltered
                                    Text("₹ \(String(format: "%.2f", sales))").foregroundColor(.green)
                                }
                                Divider()
                                HStack {
                                    NavigationLink(destination: ReportsView(viewModel: viewModel)) {
                                        Text(t("dash.reportsLink")).foregroundColor(.gpOrange)
                                    }
                                    Spacer()
                                    NavigationLink(destination: DetailedSummaryView(viewModel: viewModel)) {
                                        Text(t("dash.summaryLink")).foregroundColor(.gpOrange)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.07), radius: 4, y: 2)
                            .padding(.horizontal)

                            // Search + sort + items
                            VStack(spacing: 0) {
                                HStack {
                                    HStack {
                                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                                        TextField(t("dash.searchItems"), text: $searchText)
                                        if !searchText.isEmpty {
                                            Button(action: { searchText = "" }) {
                                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .background(Color(.systemFill))
                                    .cornerRadius(10)

                                    Menu {
                                        ForEach(SortOption.allCases, id: \.self) { o in
                                            Button(o.rawValue) { sortOption = o }
                                        }
                                    } label: {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.title3)
                                            .foregroundColor(.gpOrange)
                                    }

                                    NavigationLink(destination: ReportsView(viewModel: viewModel)) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.title3)
                                            .foregroundColor(.gpOrange)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 12)
                                .padding(.bottom, 8)

                                ForEach(selectedItems) { item in
                                    ItemStockCard(item: item, viewModel: viewModel)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.07), radius: 4, y: 2)
                            .padding(.horizontal)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                }

                // FAB
                Button(action: {
                    if authManager.isSignedIn { showingAddItem = true }
                    else { showingLoginSheet = true }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(18)
                        .background(
                            LinearGradient(colors: [.gpOrange, .gpOrangeDark], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Circle())
                        .shadow(color: .gpOrange.opacity(0.45), radius: 8, y: 4)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingNotifications) { NotificationsView() }
        .sheet(isPresented: $showingAddItem) { AddItemView(viewModel: viewModel) }
        .sheet(isPresented: $showingLoginSheet) { GoogleSignInView() }
    }
}

struct CategoryFilterChip: View {
    let name: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(name).font(.subheadline.weight(isSelected ? .semibold : .regular))
                Text("(\(count))").font(.caption).opacity(0.8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.gpOrange : Color(.tertiarySystemFill))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct ItemStockCard: View {
    let item: InventoryItem
    @ObservedObject var viewModel: InventoryViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingStockIn = false
    @State private var showingStockOut = false
    @State private var showingItemDetail = false
    @State private var showingLoginSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text(t("stock.updatedRecently"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingItemDetail = true }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text(t("stock.totalStockIn"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", viewModel.getStockIn(for: item))) \(item.priceUnit)")
                        .foregroundColor(.brown)
                }

                VStack(alignment: .leading) {
                    Text(t("stock.openingStock"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", item.openingStock)) \(item.priceUnit)")
                }
            }

            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text(t("stock.totalStockOut"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", viewModel.getStockOut(for: item))) \(item.priceUnit)")
                        .foregroundColor(.brown)
                }

                VStack(alignment: .leading) {
                    Text(t("stock.remainingStock"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        if item.isLowStock {
                            Image(systemName: item.currentStock == 0 ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(item.currentStock == 0 ? .red : .orange)
                        }
                        Text("\(String(format: "%.1f", item.currentStock)) \(item.priceUnit)")
                            .foregroundColor(item.currentStock == 0 ? .red : item.isLowStock ? .orange : .primary)
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: {
                    if authManager.isSignedIn { showingStockIn = true }
                    else { showingLoginSheet = true }
                }) {
                    Text(t("stock.btnIn"))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 1)
                        )
                }

                Button(action: {
                    if authManager.isSignedIn { showingStockOut = true }
                    else { showingLoginSheet = true }
                }) {
                    Text(t("stock.btnOut"))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red, lineWidth: 1)
                        )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.08), radius: 3)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .sheet(isPresented: $showingStockIn) {
            StockUpdateView(viewModel: viewModel, item: item, isStockIn: true)
        }
        .sheet(isPresented: $showingStockOut) {
            StockUpdateView(viewModel: viewModel, item: item, isStockIn: false)
        }
        .sheet(isPresented: $showingItemDetail) {
            NavigationView {
                ItemDetailView(viewModel: viewModel, item: item)
            }
        }
        .sheet(isPresented: $showingLoginSheet) { GoogleSignInView() }
    }
}

struct TransactionsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var searchText = ""
    @State private var selectedTransaction: Transaction?
    @State private var showingNotifications = false
    
    var filteredTransactions: [Transaction] {
        if searchText.isEmpty {
            return viewModel.transactions
        }
        return viewModel.transactions.filter {
            $0.itemName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredTransactions) { transaction in
                    Button(action: {
                        selectedTransaction = transaction
                    }) {
                        let isIn = transaction.type == .stockIn || transaction.type == .purchase
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: isIn ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                    .foregroundColor(isIn ? .green : .red)
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.itemName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    HStack {
                                        Text(transaction.type.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("•")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let godown = viewModel.categories.first(where: { $0.id == transaction.categoryId }) {
                                            Text(godown.name)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("₹ \(String(format: "%.2f", transaction.totalAmount))")
                                        .font(.headline)
                                        .foregroundColor(isIn ? .green : .red)
                                    Text("\(String(format: "%.1f", transaction.quantity)) \(t("txn.units"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if !isIn, let profit = transaction.profit {
                                        Text("\(t("txn.profit")): ₹\(String(format: "%.2f", profit))")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(profit >= 0 ? .green : .red)
                                    }
                                }
                            }

                            HStack {
                                Text(transaction.date, style: .date)
                                    .font(.caption2).foregroundColor(.secondary)
                                Text("•").foregroundColor(.secondary)
                                Text(transaction.date, style: .time)
                                    .font(.caption2).foregroundColor(.secondary)
                                Spacer()
                                if let price = transaction.pricePerUnit {
                                    Text("@ ₹\(String(format: "%.2f", price))/unit")
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .searchable(text: $searchText, prompt: t("txn.search"))
            .navigationTitle(t("txn.title"))
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { BellToolbarButton { showingNotifications = true } } }
            .sheet(isPresented: $showingNotifications) { NotificationsView() }
            .sheet(item: $selectedTransaction) { transaction in
                if let item = viewModel.items.first(where: { $0.id == transaction.itemId }) {
                    NavigationView {
                        ItemDetailView(viewModel: viewModel, item: item)
                    }
                }
            }
        }
    }
}

// MARK: - Product Analysis View

struct ProductAnalysisView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var selectedItemId: UUID? = nil
    @State private var selectedGodownId: UUID? = nil
    @State private var groupBy = "monthly"
    @State private var viewMode = "qty"

    struct AnalysisBar: Identifiable {
        let id = UUID()
        let period: String
        let sortKey: Date
        let type: String
        let qty: Double
        let value: Double
    }

    var relevantTransactions: [Transaction] {
        guard let itemId = selectedItemId else { return [] }
        return viewModel.transactions.filter {
            $0.itemId == itemId &&
            (selectedGodownId == nil || $0.categoryId == selectedGodownId)
        }
    }

    var chartBars: [AnalysisBar] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = groupBy == "monthly" ? "MMM yy" : "yyyy"

        typealias Bucket = (date: Date, inQty: Double, outQty: Double, inVal: Double, outVal: Double)
        var buckets: [String: Bucket] = [:]

        for txn in relevantTransactions {
            let key = formatter.string(from: txn.date)
            var b: Bucket = buckets[key] ?? (txn.date, 0, 0, 0, 0)
            let comps: Set<Calendar.Component> = groupBy == "monthly" ? [.year, .month] : [.year]
            b.date = cal.date(from: cal.dateComponents(comps, from: txn.date)) ?? txn.date
            if txn.type == .stockIn || txn.type == .purchase {
                b.inQty += txn.quantity; b.inVal += txn.totalAmount
            } else {
                b.outQty += txn.quantity; b.outVal += txn.totalAmount
            }
            buckets[key] = b
        }

        let sorted = buckets.sorted { $0.value.date < $1.value.date }.suffix(12)
        var bars: [AnalysisBar] = []
        for (key, b) in sorted {
            bars.append(AnalysisBar(period: key, sortKey: b.date, type: t("items.stockIn"), qty: b.inQty, value: b.inVal))
            bars.append(AnalysisBar(period: key, sortKey: b.date, type: t("items.stockOut"), qty: b.outQty, value: b.outVal))
        }
        return bars.sorted { $0.sortKey < $1.sortKey }
    }

    var selectedItemName: String {
        guard let id = selectedItemId else { return t("analysis.selectItem") }
        return viewModel.items.first(where: { $0.id == id })?.name ?? t("analysis.selectItem")
    }

    var selectedGodownName: String {
        guard let id = selectedGodownId else { return t("report.allGodowns") }
        return viewModel.categories.first(where: { $0.id == id })?.name ?? t("report.allGodowns")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ── Pickers ──
                VStack(spacing: 10) {
                    Menu {
                        ForEach(viewModel.items) { item in
                            Button(item.name) { selectedItemId = item.id }
                        }
                    } label: {
                        HStack {
                            Label(selectedItemName, systemImage: "shippingbox.fill")
                                .foregroundColor(selectedItemId == nil ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }

                    Menu {
                        Button(t("report.allGodowns")) { selectedGodownId = nil }
                        ForEach(viewModel.categories) { cat in
                            Button(cat.name) { selectedGodownId = cat.id }
                        }
                    } label: {
                        HStack {
                            Label(selectedGodownName, systemImage: "building.2")
                                .foregroundColor(.primary).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)

                // ── Period / View mode toggles ──
                HStack(spacing: 12) {
                    Picker("", selection: $groupBy) {
                        Text(t("period.monthly")).tag("monthly")
                        Text(t("period.yearly")).tag("yearly")
                    }
                    .pickerStyle(.segmented)

                    Picker("", selection: $viewMode) {
                        Text(t("analysis.quantity")).tag("qty")
                        Text(t("analysis.value")).tag("value")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                // ── Chart or empty state ──
                if selectedItemId == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis").font(.system(size: 52)).foregroundColor(.secondary)
                        Text(t("analysis.noData")).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(40)
                } else if chartBars.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis").font(.system(size: 52)).foregroundColor(.secondary)
                        Text(t("noDataAvailable")).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(40)
                } else {
                    Chart(chartBars) { bar in
                        BarMark(
                            x: .value("Period", bar.period),
                            y: .value(viewMode == "qty" ? t("analysis.quantity") : t("analysis.value"),
                                      viewMode == "qty" ? bar.qty : bar.value)
                        )
                        .foregroundStyle(by: .value("Type", bar.type))
                        .position(by: .value("Type", bar.type))
                    }
                    .chartForegroundStyleScale([t("items.stockIn"): Color.green, t("items.stockOut"): Color.red])
                    .chartLegend(position: .top)
                    .frame(height: 280)
                    .padding(.horizontal)

                    // ── Summary cards ──
                    let inBars  = chartBars.filter { $0.type == t("items.stockIn") }
                    let outBars = chartBars.filter { $0.type == t("items.stockOut") }
                    let totalInQty  = inBars.reduce(0.0)  { $0 + $1.qty }
                    let totalOutQty = outBars.reduce(0.0) { $0 + $1.qty }
                    let totalInVal  = inBars.reduce(0.0)  { $0 + $1.value }
                    let totalOutVal = outBars.reduce(0.0) { $0 + $1.value }

                    HStack(spacing: 12) {
                        AnalysisStatCard(label: t("items.stockIn"),  value: String(format: "%.0f", totalInQty),  color: .green)
                        AnalysisStatCard(label: t("items.stockOut"), value: String(format: "%.0f", totalOutQty), color: .red)
                    }
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        AnalysisStatCard(label: t("pdf.purchase"),     value: "₹\(String(format: "%.0f", totalInVal))",  color: .blue)
                        AnalysisStatCard(label: t("dash.totalSales"),  value: "₹\(String(format: "%.0f", totalOutVal))", color: .gpOrange)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(t("report.productAnalysis"))
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct AnalysisStatCard: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title3.bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct ReportsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingNotifications = false
    @State private var showingLoginSheet = false

    var reports: [(title: String, icon: String, type: String)] {[
        (t("report.dailySales"), "chart.line.uptrend.xyaxis", "Daily Sales"),
        (t("report.monthlySales"), "chart.bar", "Monthly Sales"),
        (t("report.yearlySales"), "chart.pie", "Yearly Sales"),
        (t("report.stockSummary"), "cube.box", "Stock Summary"),
        (t("report.lowStock"), "exclamationmark.triangle", "Low Stock"),
        (t("report.profitLoss"), "dollarsign.circle", "Profit & Loss")
    ]}

    var body: some View {
        List {
            Section(t("report.salesReports")) {
                ForEach(reports.prefix(3), id: \.type) { r in
                    if authManager.isSignedIn {
                        NavigationLink(destination: ReportDetailView(viewModel: viewModel, reportType: r.type)) {
                            Label(r.title, systemImage: r.icon)
                        }
                    } else {
                        Button(action: { showingLoginSheet = true }) {
                            Label(r.title, systemImage: r.icon).foregroundColor(.primary)
                        }
                    }
                }
            }
            Section(t("report.stockReports")) {
                ForEach(reports.dropFirst(3).prefix(2), id: \.type) { r in
                    if authManager.isSignedIn {
                        NavigationLink(destination: ReportDetailView(viewModel: viewModel, reportType: r.type)) {
                            Label(r.title, systemImage: r.icon)
                        }
                    } else {
                        Button(action: { showingLoginSheet = true }) {
                            Label(r.title, systemImage: r.icon).foregroundColor(.primary)
                        }
                    }
                }
            }
            Section(t("report.financialReports")) {
                if authManager.isSignedIn {
                    NavigationLink(destination: ReportDetailView(viewModel: viewModel, reportType: "Profit & Loss")) {
                        Label(t("report.profitLoss"), systemImage: "dollarsign.circle")
                    }
                } else {
                    Button(action: { showingLoginSheet = true }) {
                        Label(t("report.profitLoss"), systemImage: "dollarsign.circle").foregroundColor(.primary)
                    }
                }
            }
            Section(t("report.productAnalysis")) {
                if authManager.isSignedIn {
                    NavigationLink(destination: ProductAnalysisView(viewModel: viewModel)) {
                        Label(t("report.productAnalysis"), systemImage: "chart.bar.doc.horizontal")
                    }
                } else {
                    Button(action: { showingLoginSheet = true }) {
                        Label(t("report.productAnalysis"), systemImage: "chart.bar.doc.horizontal").foregroundColor(.primary)
                    }
                }
            }
        }
        .navigationTitle(t("report.title"))
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { BellToolbarButton { showingNotifications = true } } }
        .sheet(isPresented: $showingNotifications) { NotificationsView() }
        .sheet(isPresented: $showingLoginSheet) { GoogleSignInView() }
    }
}

struct ExportURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ReportDetailView: View {
    @ObservedObject var viewModel: InventoryViewModel
    let reportType: String
    @State private var previewURL: ExportURL?
    @State private var showingNoDataAlert = false
    @State private var selectedGodownId: UUID? = nil
    @State private var selectedDate = Date()
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedYearOnly: Int = Calendar.current.component(.year, from: Date())

    var localizedReportType: String {
        switch reportType {
        case "Daily Sales":   return t("report.dailySales")
        case "Monthly Sales": return t("report.monthlySales")
        case "Yearly Sales":  return t("report.yearlySales")
        case "Stock Summary": return t("report.stockSummary")
        case "Low Stock":     return t("report.lowStock")
        case "Profit & Loss": return t("report.profitLoss")
        default:              return reportType
        }
    }

    var selectedGodownName: String {
        guard let id = selectedGodownId,
              let cat = viewModel.categories.first(where: { $0.id == id }) else { return "" }
        return cat.name
    }

    var filteredItems: [InventoryItem] {
        guard let id = selectedGodownId else { return viewModel.items }
        return viewModel.items.filter { $0.categoryId == id }
    }

    var filteredTransactions: [Transaction] {
        var txns = selectedGodownId == nil ? viewModel.transactions : viewModel.transactions.filter { $0.categoryId == selectedGodownId! }
        let cal = Calendar.current
        switch reportType {
        case "Daily Sales":
            txns = txns.filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
        case "Monthly Sales":
            txns = txns.filter { cal.component(.year, from: $0.date) == selectedYear && cal.component(.month, from: $0.date) == selectedMonth }
        case "Yearly Sales":
            txns = txns.filter { cal.component(.year, from: $0.date) == selectedYearOnly }
        default: break
        }
        return txns
    }

    // MARK: Structured data for table PDF
    var reportHeaders: [String] {
        switch reportType {
        case "Daily Sales", "Monthly Sales", "Yearly Sales":
            return [t("pdf.item"), t("pdf.qty"), t("pdf.unit"), t("pdf.pricePerUnit"), t("pdf.amount"), t("pdf.date")]
        case "Stock Summary":
            return [t("pdf.item"), t("pdf.unit"), t("pdf.opening"), t("pdf.currStock"), t("pdf.purchaseVal"), t("pdf.value")]
        case "Low Stock":
            return [t("pdf.item"), t("pdf.unit"), t("pdf.currentStock")]
        case "Profit & Loss":
            return [t("pdf.item"), t("pdf.qty"), t("pdf.unit"), t("pdf.sellPrice"), t("pdf.purchase"), t("pdf.profit")]
        default:
            return []
        }
    }

    var reportRows: [[String]] {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .none
        switch reportType {
        case "Daily Sales", "Monthly Sales", "Yearly Sales":
            return filteredTransactions
                .filter { $0.type == .sale || $0.type == .stockOut }
                .map { txn in [
                    txn.itemName,
                    String(format: "%.1f", txn.quantity),
                    viewModel.items.first(where: { $0.id == txn.itemId })?.priceUnit ?? "",
                    txn.pricePerUnit.map { "₹\(String(format: "%.2f", $0))" } ?? "-",
                    "₹\(String(format: "%.2f", txn.totalAmount))",
                    df.string(from: txn.date)
                ]}
        case "Stock Summary":
            return filteredItems.map { item in [
                item.name,
                item.priceUnit,
                String(format: "%.1f", item.openingStock),
                String(format: "%.1f", item.currentStock),
                item.purchasePrice.map { "₹\(String(format: "%.2f", $0))" } ?? "-",
                "₹\(String(format: "%.2f", item.currentStock * (item.purchasePrice ?? 0)))"
            ]}
        case "Low Stock":
            return filteredItems.filter { $0.isLowStock }.map { item in [
                item.name, item.priceUnit, String(format: "%.1f", item.currentStock)
            ]}
        case "Profit & Loss":
            return filteredTransactions
                .filter { $0.type == .sale || $0.type == .stockOut }
                .map { txn in
                    let item = viewModel.items.first(where: { $0.id == txn.itemId })
                    return [
                        txn.itemName,
                        String(format: "%.1f", txn.quantity),
                        item?.priceUnit ?? "",
                        txn.pricePerUnit.map { "₹\(String(format: "%.2f", $0))" } ?? "-",
                        item?.purchasePrice.map { "₹\(String(format: "%.2f", $0))" } ?? "-",
                        txn.profit.map { "₹\(String(format: "%.2f", $0))" } ?? "-"
                    ]
                }
        default:
            return []
        }
    }

    var reportSummary: [(String, String)] {
        switch reportType {
        case "Daily Sales", "Monthly Sales", "Yearly Sales":
            let total = filteredTransactions.filter { $0.type == .sale || $0.type == .stockOut }.reduce(0) { $0 + $1.totalAmount }
            return [(t("report.totalTransactions"), "\(filteredTransactions.filter { $0.type == .sale || $0.type == .stockOut }.count)"),
                    (t("report.totalSalesAmount"), "₹\(String(format: "%.2f", total))")]
        case "Stock Summary":
            let value = filteredItems.reduce(0.0) { $0 + $1.currentStock * ($1.purchasePrice ?? 0) }
            return [(t("summary.totalItems"), "\(filteredItems.count)"),
                    (t("summary.totalStockValue"), "₹\(String(format: "%.2f", value))")]
        case "Low Stock":
            let low = filteredItems.filter { $0.isLowStock }
            return [(t("report.lowStock"), "\(low.count)"), (t("report.outOfStock"), "\(low.filter { $0.currentStock == 0 }.count)")]
        case "Profit & Loss":
            let sales = filteredTransactions.filter { $0.type == .sale || $0.type == .stockOut }.reduce(0.0) { $0 + $1.totalAmount }
            let purchase = filteredTransactions.filter { $0.type == .purchase || $0.type == .stockIn }.reduce(0.0) { $0 + $1.totalAmount }
            let profit = filteredTransactions.filter { $0.type == .sale || $0.type == .stockOut }.reduce(0.0) { $0 + ($1.profit ?? 0) }
            return [(t("summary.totalSales"), "₹\(String(format: "%.2f", sales))"),
                    (t("summary.totalPurchase"), "₹\(String(format: "%.2f", purchase))"),
                    (t("summary.netProfit"), "₹\(String(format: "%.2f", profit))")]
        default:
            return []
        }
    }

    // In-app display content (text-based cards)
    var reportContent: String {
        switch reportType {
        case "Daily Sales", "Monthly Sales", "Yearly Sales":
            let txns = filteredTransactions.filter { $0.type == .sale || $0.type == .stockOut }
            var r = "Total Sales: ₹\(String(format: "%.2f", txns.reduce(0) { $0 + $1.totalAmount }))\n\n"
            for txn in txns.prefix(30) {
                r += "\(txn.itemName)\nQty: \(String(format: "%.1f", txn.quantity))  Amount: ₹\(String(format: "%.2f", txn.totalAmount))\nDate: \(txn.date.formatted())\n\n"
            }
            return r
        case "Stock Summary":
            var r = "Total Items: \(filteredItems.count)\n\n"
            for item in filteredItems {
                r += "\(item.name)\nStock: \(String(format: "%.1f", item.currentStock)) \(item.priceUnit)"
                if let p = item.purchasePrice { r += "  Purchase: ₹\(String(format: "%.2f", p))" }
                r += "\n\n"
            }
            return r
        case "Low Stock":
            let low = filteredItems.filter { $0.isLowStock }
            if low.isEmpty { return t("noLowStock") }
            return low.map { "\($0.name)\nStock: \(String(format: "%.1f", $0.currentStock)) \($0.priceUnit)" }.joined(separator: "\n\n")
        case "Profit & Loss":
            let sales = filteredTransactions.filter { $0.type == .sale || $0.type == .stockOut }.reduce(0.0) { $0 + $1.totalAmount }
            let purchase = filteredTransactions.filter { $0.type == .purchase || $0.type == .stockIn }.reduce(0.0) { $0 + $1.totalAmount }
            let profit = filteredTransactions.filter { $0.type == .sale || $0.type == .stockOut }.reduce(0.0) { $0 + ($1.profit ?? 0) }
            return "Total Sales: ₹\(String(format: "%.2f", sales))\n\nTotal Purchases: ₹\(String(format: "%.2f", purchase))\n\nNet Profit: ₹\(String(format: "%.2f", profit))"
        default:
            return ""
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LinearGradient(colors: [.gpOrange, .gpOrangeDark], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 80)
                        .overlay(
                            Text(localizedReportType).font(.title2.bold()).foregroundColor(.white).padding(),
                            alignment: .bottomLeading
                        )

                    // Godown filter
                    Menu {
                        Button(action: { selectedGodownId = nil }) {
                            HStack {
                                Text(t("report.allGodowns"))
                                if selectedGodownId == nil { Image(systemName: "checkmark") }
                            }
                        }
                        Divider()
                        ForEach(viewModel.categories) { cat in
                            Button(action: { selectedGodownId = cat.id }) {
                                HStack {
                                    Text(cat.name)
                                    if selectedGodownId == cat.id { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill").foregroundColor(.gpOrange).font(.title3)
                            Text(selectedGodownName.isEmpty ? t("report.allGodowns") : selectedGodownName)
                                .font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(.systemBackground)).cornerRadius(12)
                        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.07), radius: 4, y: 2)
                    }
                    .padding()

                    // Date / period picker for sales reports
                    if reportType == "Daily Sales" {
                        DatePicker(t("report.selectDate"), selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color(.systemBackground)).cornerRadius(12)
                            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.07), radius: 4, y: 2)
                            .padding(.horizontal)
                    } else if reportType == "Monthly Sales" {
                        HStack {
                            Text(t("report.selectMonth"))
                                .font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { m in
                                    Text(Calendar.current.monthSymbols[m - 1]).tag(m)
                                }
                            }
                            .pickerStyle(.menu)
                            Picker("", selection: $selectedYear) {
                                let cur = Calendar.current.component(.year, from: Date())
                                ForEach((cur - 5)...cur, id: \.self) { y in
                                    Text(String(y)).tag(y)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(.systemBackground)).cornerRadius(12)
                        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.07), radius: 4, y: 2)
                        .padding(.horizontal)
                    } else if reportType == "Yearly Sales" {
                        HStack {
                            Text(t("report.selectYear"))
                                .font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $selectedYearOnly) {
                                let cur = Calendar.current.component(.year, from: Date())
                                ForEach((cur - 5)...cur, id: \.self) { y in
                                    Text(String(y)).tag(y)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(.systemBackground)).cornerRadius(12)
                        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.07), radius: 4, y: 2)
                        .padding(.horizontal)
                    }

                    // In-app content cards
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(reportContent.components(separatedBy: "\n\n"), id: \.self) { block in
                            if !block.trimmingCharacters(in: .whitespaces).isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(block.components(separatedBy: "\n"), id: \.self) { line in
                                        if !line.isEmpty {
                                            Text(line)
                                                .font(line.contains("₹") || line.contains(":") ? .subheadline : .subheadline.bold())
                                                .foregroundColor(line.contains("₹") ? .secondary : .primary)
                                        }
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.06), radius: 3, y: 1)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.secondarySystemBackground))

            Button(action: {
                if reportRows.isEmpty {
                    showingNoDataAlert = true
                    return
                }
                let url = viewModel.generateStructuredPDF(
                    title: localizedReportType,
                    godownName: selectedGodownName,
                    headers: reportHeaders,
                    rows: reportRows,
                    summary: reportSummary
                )
                if let url = url { previewURL = ExportURL(url: url) }
            }) {
                Label(t("report.exportPDF"), systemImage: "arrow.up.doc")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [.gpOrange, .gpOrangeDark], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(16)
                    .shadow(color: .gpOrange.opacity(0.35), radius: 6, y: 3)
            }
            .padding()
        }
        .navigationTitle(localizedReportType)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewURL) { item in
            PDFPreviewView(url: item.url)
        }
        .alert(t("noDataAvailable"), isPresented: $showingNoDataAlert) {
            Button(t("action.ok"), role: .cancel) {}
        }
    }
}

struct ReportRow: View {
    // kept for compatibility
    let title: String
    let icon: String
    @ObservedObject var viewModel: InventoryViewModel
    let reportType: String
    var body: some View { EmptyView() }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PDFPreviewView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let pdfView = PDFView()
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        let viewController = UIViewController()
        viewController.view = pdfView
        viewController.navigationItem.title = "PDF Preview"
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: context.coordinator,
            action: #selector(Coordinator.shareAction)
        )
        
        let navController = UINavigationController(rootViewController: viewController)
        navController.navigationBar.prefersLargeTitles = false
        
        let coordinator = context.coordinator
        coordinator.url = url
        coordinator.navController = navController
        
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var url: URL?
        var navController: UINavigationController?
        
        @objc func shareAction() {
            guard let url = url, let navController = navController else { return }
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            navController.present(activityVC, animated: true)
        }
    }
}

struct DetailedSummaryView: View {
    @ObservedObject var viewModel: InventoryViewModel

    var body: some View {
        List {
            Section(t("summary.allGodowns")) {
                HStack {
                    Text(t("summary.totalItems"))
                    Spacer()
                    Text("\(viewModel.items.count)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text(t("summary.totalStockValue"))
                    Spacer()
                    Text("₹ \(String(format: "%.2f", calculateTotalValue()))")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text(t("summary.totalPurchase"))
                    Spacer()
                    Text("₹ \(String(format: "%.2f", viewModel.allGodownsTotalPurchase))")
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }

                HStack {
                    Text(t("summary.totalSales"))
                    Spacer()
                    Text("₹ \(String(format: "%.2f", viewModel.allGodownsTotalSales))")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                HStack {
                    Text(t("summary.netProfit"))
                    Spacer()
                    Text("₹ \(String(format: "%.2f", viewModel.allGodownsTotalProfit))")
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.allGodownsTotalProfit >= 0 ? .green : .red)
                }
            }

            Section(t("summary.recentTxns")) {
                ForEach(viewModel.transactions.prefix(30)) { transaction in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.itemName)
                                .font(.subheadline)
                            HStack {
                                Text(transaction.type.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let godown = viewModel.categories.first(where: { $0.id == transaction.categoryId }) {
                                    Text(godown.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("₹ \(String(format: "%.2f", transaction.totalAmount))")
                                .fontWeight(.semibold)
                                .foregroundColor(transaction.type == .stockIn || transaction.type == .purchase ? .green : .red)
                            Text("\(String(format: "%.1f", transaction.quantity)) \(t("txn.units"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(t("summary.title"))
    }

    func calculateTotalValue() -> Double {
        viewModel.items.reduce(0) { total, item in
            total + (item.currentStock * (item.sellingPrice ?? 0))
        }
    }
}

struct InventoryListView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingAddItem = false
    @State private var showingLoginSheet = false
    @State private var searchText = ""
    @State private var selectedCategory = "All Items"
    @State private var showingNotifications = false
    let allItemsKey = "All Items"

    var filteredItems: [InventoryItem] {
        var items: [InventoryItem]
        if selectedCategory == allItemsKey {
            items = viewModel.items
        } else if let cat = viewModel.categories.first(where: { $0.name == selectedCategory }) {
            items = viewModel.items.filter { $0.categoryId == cat.id }
        } else {
            items = viewModel.items
        }
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return items
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CategoryFilterChip(
                            name: t("items.allItems"),
                            count: viewModel.items.count,
                            isSelected: selectedCategory == allItemsKey
                        ) { selectedCategory = allItemsKey }

                        ForEach(viewModel.categories) { cat in
                            CategoryFilterChip(
                                name: cat.name,
                                count: viewModel.items.filter { $0.categoryId == cat.id }.count,
                                isSelected: selectedCategory == cat.name
                            ) { selectedCategory = cat.name }
                        }
                    }
                    .padding()
                }
                .background(Color(.secondarySystemBackground))

                List {
                    ForEach(filteredItems) { item in
                        NavigationLink(destination: ItemDetailView(viewModel: viewModel, item: item)) {
                            InventoryItemRow(item: item, viewModel: viewModel)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .searchable(text: $searchText, prompt: t("items.searchItems"))
            }
            .navigationTitle(t("items.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        BellToolbarButton { showingNotifications = true }
                        Button(action: {
                            if authManager.isSignedIn { showingAddItem = true }
                            else { showingLoginSheet = true }
                        }) { Image(systemName: "plus") }
                    }
                }
            }
            .sheet(isPresented: $showingNotifications) { NotificationsView() }
            .sheet(isPresented: $showingAddItem) { AddItemView(viewModel: viewModel) }
            .sheet(isPresented: $showingLoginSheet) { GoogleSignInView() }
        }
    }

    func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteItem(filteredItems[index])
        }
    }
}

struct InventoryItemRow: View {
    let item: InventoryItem
    @ObservedObject var viewModel: InventoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        if item.isLowStock {
                            Image(systemName: item.currentStock == 0 ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(item.currentStock == 0 ? .red : .orange)
                        }
                        Text("\(String(format: "%.1f", item.currentStock)) \(item.priceUnit)")
                            .font(.headline)
                            .foregroundColor(item.currentStock == 0 ? .red : item.isLowStock ? .orange : .primary)
                    }
                    if let price = item.sellingPrice {
                        Text("₹\(String(format: "%.2f", price))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text(t("items.stockIn"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", viewModel.getStockIn(for: item)))")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading) {
                    Text(t("items.stockOut"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", viewModel.getStockOut(for: item)))")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddItemView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var purchasePrice = ""
    @State private var mrp = ""
    @State private var priceUnit = "Piece"
    @State private var openingStock = ""
    @State private var lowStockThreshold = ""
    @State private var selectedCategoryId: UUID? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(t("item.itemDetails")) {
                    TextField(t("item.itemNamePlaceholder"), text: $name)
                }

                Section {
                    if viewModel.categories.isEmpty {
                        Text(t("item.noGodowns"))
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        Picker(t("item.godownCategory"), selection: $selectedCategoryId) {
                            ForEach(viewModel.categories) { cat in
                                let count = viewModel.items.filter { $0.categoryId == cat.id }.count
                                Text("\(cat.name)  (\(count) \(t("dash.items")))").tag(Optional(cat.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.gpOrange)
                    }
                } header: {
                    Text(t("item.godownHeader"))
                }

                Section(t("item.pricing")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("item.purchasePrice"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("item.mrp"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $mrp)
                            .keyboardType(.decimalPad)
                    }

                    Picker(t("item.priceUnit"), selection: $priceUnit) {
                        ForEach(PriceUnit.units, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                }

                Section(t("item.stock")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("item.openingStock"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0", text: $openingStock)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("item.lowStockThreshold"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let defaultHint = (Double(openingStock) ?? 0) > 0
                            ? "Default: \(String(format: "%.1f", (Double(openingStock) ?? 0) * 0.20))"
                            : "Default: 20% of opening stock"
                        TextField(defaultHint, text: $lowStockThreshold)
                            .keyboardType(.decimalPad)
                        Text(t("item.lowStockThresholdHint"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(t("item.addItem"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedCategoryId == nil {
                    selectedCategoryId = viewModel.currentCategoryId ?? viewModel.categories.first?.id
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("action.save")) { saveItem() }
                        .disabled(!isValid)
                }
            }
        }
    }

    var isValid: Bool {
        !name.isEmpty && Double(openingStock) != nil && selectedCategoryId != nil
    }

    func saveItem() {
        guard let categoryId = selectedCategoryId ?? viewModel.currentCategoryId else { return }
        let stock = Double(openingStock) ?? 0
        let item = InventoryItem(
            categoryId: categoryId,
            name: name,
            purchasePrice: Double(purchasePrice),
            mrp: Double(mrp),
            sellingPrice: nil,
            priceUnit: priceUnit,
            openingStock: stock,
            currentStock: stock,
            dateAdded: Date(),
            lowStockThreshold: Double(lowStockThreshold)
        )
        viewModel.addItem(item)
        if stock > 0 {
            let txn = Transaction(
                categoryId: categoryId,
                itemId: item.id,
                itemName: item.name,
                type: .stockIn,
                quantity: stock,
                pricePerUnit: item.purchasePrice,
                totalAmount: (item.purchasePrice ?? 0) * stock,
                date: item.dateAdded
            )
            viewModel.addTransaction(txn)
        }
        dismiss()
    }
}

struct ItemDetailView: View {
    @ObservedObject var viewModel: InventoryViewModel
    let item: InventoryItem

    @State private var showingStockIn = false
    @State private var showingStockOut = false
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) var dismiss

    var itemTransactions: [Transaction] {
        viewModel.transactions.filter { $0.itemId == item.id }
    }

    var body: some View {
        List {
            Section(t("item.info")) {
                DetailRow(label: t("item.name"), value: item.name)
                if let price = item.purchasePrice {
                    DetailRow(label: t("item.purchasePriceLabel"), value: "₹\(String(format: "%.2f", price))")
                }
                if let price = item.mrp {
                    DetailRow(label: t("item.mrpLabel"), value: "₹\(String(format: "%.2f", price))")
                }
                if let price = item.sellingPrice {
                    DetailRow(label: t("item.sellingPrice"), value: "₹\(String(format: "%.2f", price))")
                }
                DetailRow(label: t("item.priceUnitLabel"), value: item.priceUnit)
                DetailRow(label: t("item.openingStockLabel"), value: "\(String(format: "%.1f", item.openingStock))")
                DetailRow(label: t("item.currentStockLabel"), value: "\(String(format: "%.1f", item.currentStock))")
                if let godown = viewModel.categories.first(where: { $0.id == item.categoryId }) {
                    DetailRow(label: t("item.godownLabel"), value: godown.name)
                }
            }

            Section(t("item.stockMovements")) {
                DetailRow(label: t("item.totalStockIn"), value: "\(String(format: "%.1f", viewModel.getStockIn(for: item)))")
                DetailRow(label: t("item.totalStockOut"), value: "\(String(format: "%.1f", viewModel.getStockOut(for: item)))")
            }

            Section(t("txn.title")) {
                if itemTransactions.isEmpty {
                    Text(t("item.noTransactions"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(itemTransactions.prefix(30)) { txn in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(txn.type.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(txn.type == .stockIn || txn.type == .purchase ? .green : .red)
                                HStack(spacing: 4) {
                                    Text(txn.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let godown = viewModel.categories.first(where: { $0.id == txn.categoryId }) {
                                        Text("• \(godown.name)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(String(format: "%.1f", txn.quantity)) \(t("txn.units"))")
                                    .font(.subheadline)
                                if txn.totalAmount > 0 {
                                    Text("₹\(String(format: "%.2f", txn.totalAmount))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button(action: { showingStockIn = true }) {
                    Label(t("item.stockInLabel"), systemImage: "arrow.down.circle")
                }

                Button(action: { showingStockOut = true }) {
                    Label(t("item.stockOutLabel"), systemImage: "arrow.up.circle")
                }

                Button(action: { showingEdit = true }) {
                    Label(t("item.editItem"), systemImage: "pencil")
                }

                Button(action: { showingDeleteAlert = true }) {
                    Label(t("item.deleteItem"), systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(item.name)
        .sheet(isPresented: $showingStockIn) {
            StockUpdateView(viewModel: viewModel, item: item, isStockIn: true)
        }
        .sheet(isPresented: $showingStockOut) {
            StockUpdateView(viewModel: viewModel, item: item, isStockIn: false)
        }
        .sheet(isPresented: $showingEdit) {
            EditItemView(viewModel: viewModel, item: item)
        }
        .alert(t("item.deleteItem"), isPresented: $showingDeleteAlert) {
            Button(t("action.cancel"), role: .cancel) {}
            Button(t("action.delete"), role: .destructive) {
                viewModel.deleteItem(item)
                dismiss()
            }
        } message: {
            Text(String(format: t("item.deleteConfirm"), item.name))
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct StockUpdateView: View {
    @ObservedObject var viewModel: InventoryViewModel
    let item: InventoryItem
    let isStockIn: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var quantity = ""
    @State private var pricePerUnit = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(isStockIn ? t("item.stockInLabel") : t("item.stockOutLabel")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("stockUpdate.qty"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0", text: $quantity)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("stockUpdate.priceOptional"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $pricePerUnit)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Text("\(t("stockUpdate.currentStock")): \(String(format: "%.1f", item.currentStock)) \(item.priceUnit)")
                        .foregroundColor(.secondary)

                    if !isStockIn {
                        if let purchasePrice = item.purchasePrice {
                            Text("\(t("stockUpdate.purchasePrice")): ₹\(String(format: "%.2f", purchasePrice))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        if let mrp = item.mrp {
                            Text("\(t("stockUpdate.mrp")): ₹\(String(format: "%.2f", mrp))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        if let sellingPrice = item.sellingPrice {
                            Text("\(t("stockUpdate.sellingPrice")): ₹\(String(format: "%.2f", sellingPrice))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }

                        if let qty = Double(quantity) {
                            if item.currentStock - qty < 0 {
                                Text("\(t("stockUpdate.insufficientStock")): \(String(format: "%.1f", item.currentStock))")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isStockIn ? t("item.stockInLabel") : t("item.stockOutLabel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("action.save")) {
                        updateStock()
                    }
                    .disabled(!isValid)
                }
            }
            .alert(t("auth.error"), isPresented: $showingError) {
                Button(t("action.ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    var isValid: Bool {
        guard let qty = Double(quantity), qty > 0 else { return false }
        if !isStockIn {
            return item.currentStock >= qty
        }
        return true
    }
    
    func updateStock() {
        if let qty = Double(quantity) {
            let price = Double(pricePerUnit)
            if isStockIn {
                viewModel.stockIn(for: item, quantity: qty, pricePerUnit: price)
                dismiss()
            } else {
                let success = viewModel.stockOut(for: item, quantity: qty, pricePerUnit: price)
                if success {
                    dismiss()
                } else {
                    errorMessage = t("stockUpdate.errorMsg")
                    showingError = true
                }
            }
        }
    }
}

struct EditItemView: View {
    @ObservedObject var viewModel: InventoryViewModel
    let item: InventoryItem
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var purchasePrice: String
    @State private var mrp: String
    @State private var sellingPrice: String
    @State private var priceUnit: String
    @State private var lowStockThreshold: String

    init(viewModel: InventoryViewModel, item: InventoryItem) {
        self.viewModel = viewModel
        self.item = item
        _name = State(initialValue: item.name)
        _purchasePrice = State(initialValue: item.purchasePrice != nil ? String(item.purchasePrice!) : "")
        _mrp = State(initialValue: item.mrp != nil ? String(item.mrp!) : "")
        _sellingPrice = State(initialValue: item.sellingPrice != nil ? String(item.sellingPrice!) : "")
        _priceUnit = State(initialValue: item.priceUnit)
        _lowStockThreshold = State(initialValue: item.lowStockThreshold != nil ? String(item.lowStockThreshold!) : "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(t("item.itemDetails")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("item.itemName"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(t("item.itemName"), text: $name)
                    }
                }

                Section(t("item.pricing")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("item.purchasePrice"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("item.mrp"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $mrp)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("item.sellingPrice"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $sellingPrice)
                            .keyboardType(.decimalPad)
                    }

                    Picker(t("item.priceUnit"), selection: $priceUnit) {
                        ForEach(PriceUnit.units, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                }

                Section(t("item.stock")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("item.lowStockThreshold"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let defaultHint = "Default: \(String(format: "%.1f", item.effectiveLowStockThreshold))"
                        TextField(defaultHint, text: $lowStockThreshold)
                            .keyboardType(.decimalPad)
                        Text(t("item.lowStockThresholdHint"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(t("item.editItemTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("action.save")) {
                        saveChanges()
                    }
                }
            }
        }
    }

    func saveChanges() {
        var updatedItem = item
        updatedItem.name = name
        updatedItem.purchasePrice = Double(purchasePrice)
        updatedItem.mrp = Double(mrp)
        updatedItem.sellingPrice = Double(sellingPrice)
        updatedItem.priceUnit = priceUnit
        updatedItem.lowStockThreshold = Double(lowStockThreshold)
        viewModel.updateItem(updatedItem)
        dismiss()
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var appSettings: AppSettings
    @State private var showingAddCategory = false
    @State private var showingLogoutAlert = false
    @State private var showingLoginSheet = false
    @State private var editingBusinessName = false
    @State private var draftBusinessName = ""
    @State private var showingNotifications = false
    @State private var editingAddress = false
    @State private var draftAddress = ""

    var body: some View {
        NavigationView {
            List {
                // User profile section
                Section {
                    if !authManager.isSignedIn {
                        Button(action: { showingLoginSheet = true }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gpOrange)
                                VStack(alignment: .leading) {
                                    Text(t("auth.signIn"))
                                        .font(.headline)
                                    Text(t("auth.syncData"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 8)
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        HStack {
                            if let imageURL = authManager.userProfileImageURL {
                                AsyncImage(url: imageURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill").font(.largeTitle).foregroundColor(.gpOrange)
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill").font(.largeTitle).foregroundColor(.gpOrange)
                            }
                            VStack(alignment: .leading) {
                                Text(authManager.userDisplayName).font(.headline)
                                Text(authManager.userEmail).font(.caption).foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Business profile
                Section(t("settings.businessProfile")) {
                    if editingBusinessName {
                        HStack {
                            TextField(t("settings.businessNamePlaceholder"), text: $draftBusinessName).textFieldStyle(.plain)
                            Spacer()
                            Button(t("action.save")) {
                                viewModel.updateBusinessName(draftBusinessName)
                                editingBusinessName = false
                            }
                            .foregroundColor(.gpOrange).fontWeight(.semibold)
                        }
                    } else {
                        HStack {
                            Text(viewModel.businessName.isEmpty ? t("settings.setBusinessName") : viewModel.businessName)
                                .foregroundColor(viewModel.businessName.isEmpty ? .secondary : .primary)
                            Spacer()
                            Button(t("action.edit")) {
                                if authManager.isSignedIn {
                                    draftBusinessName = viewModel.businessName
                                    editingBusinessName = true
                                } else { showingLoginSheet = true }
                            }
                            .foregroundColor(.gpOrange)
                        }
                    }

                    if editingAddress {
                        HStack {
                            TextField(t("settings.businessAddressPlaceholder"), text: $draftAddress).textFieldStyle(.plain)
                            Spacer()
                            Button(t("action.save")) {
                                viewModel.updateBusinessAddress(draftAddress)
                                editingAddress = false
                            }
                            .foregroundColor(.gpOrange).fontWeight(.semibold)
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("settings.addressLabel")).font(.caption).foregroundColor(.secondary)
                                Text(viewModel.businessAddress.isEmpty ? t("settings.setAddress") : viewModel.businessAddress)
                                    .foregroundColor(viewModel.businessAddress.isEmpty ? .secondary : .primary)
                                    .font(.subheadline)
                            }
                            Spacer()
                            Button(t("action.edit")) {
                                if authManager.isSignedIn {
                                    draftAddress = viewModel.businessAddress
                                    editingAddress = true
                                } else { showingLoginSheet = true }
                            }
                            .foregroundColor(.gpOrange)
                        }
                    }
                }

                // Categories
                Section(t("settings.godowns")) {
                    ForEach(viewModel.categories) { cat in
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.gpOrange)
                                .font(.caption)
                            Text(cat.name)
                            Spacer()
                            Text("\(viewModel.items.filter { $0.categoryId == cat.id }.count) \(t("dash.items"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteCategory)

                    Button(action: {
                        if authManager.isSignedIn { showingAddCategory = true }
                        else { showingLoginSheet = true }
                    }) {
                        Label(t("settings.addGodown"), systemImage: "plus.circle.fill")
                            .foregroundColor(.gpOrange)
                    }
                }

                // Appearance
                Section(t("settings.appearance")) {
                    Picker(t("settings.theme"), selection: $appSettings.theme) {
                        Text(t("theme.system")).tag("system")
                        Text(t("theme.light")).tag("light")
                        Text(t("theme.dark")).tag("dark")
                    }
                    Picker(t("settings.language"), selection: $appSettings.language) {
                        Text(t("lang.en")).tag("en")
                        Text(t("lang.hi")).tag("hi")
                        Text(t("lang.mr")).tag("mr")
                        Text(t("lang.gu")).tag("gu")
                        Text(t("lang.pa")).tag("pa")
                    }
                }

                // Support
                Section(t("settings.support")) {
                    NavigationLink(destination: AppSupportView()) {
                        Label(t("settings.appSupport"), systemImage: "questionmark.circle")
                    }
                    NavigationLink(destination: AboutView()) {
                        Label(t("settings.about"), systemImage: "info.circle")
                    }
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label(t("settings.privacy"), systemImage: "hand.raised")
                    }
                    NavigationLink(destination: TermsView()) {
                        Label(t("settings.terms"), systemImage: "doc.text")
                    }
                }

                if authManager.isSignedIn {
                    Section {
                        Button(action: { showingLogoutAlert = true }) {
                            Label(t("auth.signOut"), systemImage: "arrow.right.square").foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(t("settings.title"))
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { BellToolbarButton { showingNotifications = true } } }
            .sheet(isPresented: $showingNotifications) { NotificationsView() }
            .sheet(isPresented: $showingAddCategory) { AddCategoryView(viewModel: viewModel) }
            .sheet(isPresented: $showingLoginSheet) { GoogleSignInView() }
            .alert(t("auth.signOut"), isPresented: $showingLogoutAlert) {
                Button(t("action.cancel"), role: .cancel) {}
                Button(t("auth.signOut"), role: .destructive) { authManager.signOut() }
            } message: {
                Text(t("auth.signOutConfirm"))
            }
        }
    }

    func deleteCategory(at offsets: IndexSet) {
        for index in offsets {
            let cat = viewModel.categories[index]
            if viewModel.categories.count > 1 {
                viewModel.deleteCategory(cat)
            }
        }
    }
}

struct GoogleSignInView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // Top brand area
                LinearGradient(colors: [.gpOrange, .gpOrangeDark], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 220)
                    .overlay(
                        VStack(spacing: 12) {
                            GodownPeLogoMark(size: 68)
                            HStack(spacing: 0) {
                                Text("Godown").font(.system(size: 28, weight: .black)).foregroundColor(.white)
                                Text("Pe").font(.system(size: 28, weight: .black)).foregroundColor(.white.opacity(0.75))
                            }
                        }
                    )
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 28, bottomTrailingRadius: 28, topTrailingRadius: 0))

                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text(t("auth.welcomeBack"))
                            .font(.title2.bold())
                        Text(t("auth.signInDesc"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: {
                        Task {
                            await authManager.signIn()
                            if authManager.isSignedIn { dismiss() }
                        }
                    }) {
                        HStack(spacing: 12) {
                            if authManager.isLoading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "g.circle.fill").font(.title2)
                                Text(t("auth.continueWithGoogle")).fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(colors: [.gpOrange, .gpOrangeDark], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                        .shadow(color: .gpOrange.opacity(0.35), radius: 6, y: 3)
                    }
                    .padding(.horizontal)
                    .disabled(authManager.isLoading)

                    Spacer()

                    Text(t("auth.dataPrivate"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                .padding(.top, 16)
            }
            .navigationTitle(t("auth.signInTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("action.cancel")) { dismiss() }
                }
            }
        }
    }
}

struct AppSupportView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                Text("• Add your first item from the Items tab")
                Text("• Set opening stock for each item")
                Text("• Track stock in and out from the Stock tab")
                Text("• View reports and summaries")
            }

            Section("Common Questions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How do I add an item?")
                        .fontWeight(.semibold)
                    Text("Go to Items tab and tap the + button. Fill in item details and opening stock.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("How do I update stock?")
                        .fontWeight(.semibold)
                    Text("In Stock tab, use the In/Out buttons on each item card to add or remove stock.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Can I manage multiple businesses?")
                        .fontWeight(.semibold)
                    Text("Yes! Add businesses in Settings and switch between them using the business picker.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Contact Support") {
                Link(destination: URL(string: "mailto:rajat.enzyme@gmail.com")!) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.gpOrange)
                            .frame(width: 24)
                        Text("rajat.enzyme@gmail.com")
                    }
                }
                Text("Hours: Mon-Sat 9AM-7PM IST")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(t("settings.appSupport"))
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    GodownPeLogoMark(size: 72)
                    HStack(spacing: 0) {
                        Text("Godown").font(.system(size: 26, weight: .black))
                        Text("Pe").font(.system(size: 26, weight: .black)).foregroundColor(.gpOrange)
                    }
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            Section("About") {
                Text("GodownPe helps small business owners track their godown stock easily. Manage multiple shops, record every stock movement, and get instant reports — all from your phone.")
            }

            Section("Developer") {
                HStack {
                    Image(systemName: "person.fill").foregroundColor(.gpOrange).frame(width: 24)
                    Text("Rajat Mittal").fontWeight(.semibold)
                }
                Link(destination: URL(string: "mailto:rajat.enzyme@gmail.com")!) {
                    HStack {
                        Image(systemName: "envelope.fill").foregroundColor(.gpOrange).frame(width: 24)
                        Text("rajat.enzyme@gmail.com")
                    }
                }
                Text("Made with care for small businesses in India")
                    .font(.caption).foregroundColor(.secondary)
                Text("© 2026 GodownPe. All rights reserved.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .navigationTitle(t("settings.about"))
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: March 22, 2026")
                    .foregroundColor(.secondary)
                
                Group {
                    Text("Data Collection")
                        .font(.headline)
                    Text("We collect only the data necessary to provide our inventory management services. This includes business information, item details, and transaction records that you enter into the app.")
                    
                    Text("Data Storage")
                        .font(.headline)
                    Text("All your data is stored locally on your device. We do not transmit your business data to external servers. Your privacy and data security are our top priorities.")
                    
                    Text("Data Usage")
                        .font(.headline)
                    Text("Your data is used solely for providing inventory management functionality within the app. We do not share, sell, or distribute your data to third parties.")
                    
                    Text("Your Rights")
                        .font(.headline)
                    Text("You have complete control over your data. You can delete items, businesses, or all data at any time through the app interface.")
                }
            }
            .padding()
        }
        .navigationTitle(t("settings.privacy"))
    }
}

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Service")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: March 22, 2026")
                    .foregroundColor(.secondary)
                
                Group {
                    Text("Acceptance of Terms")
                        .font(.headline)
                    Text("By using this app, you agree to these terms of service. If you do not agree, please discontinue use of the app.")
                    
                    Text("Service Description")
                        .font(.headline)
                    Text("GodownPe provides tools for tracking business inventory, sales, and purchases. The app is provided 'as is' without warranties of any kind.")
                    
                    Text("User Responsibilities")
                        .font(.headline)
                    Text("You are responsible for maintaining accurate records, backing up your data, and using the app in compliance with applicable laws.")
                    
                    Text("Limitation of Liability")
                        .font(.headline)
                    Text("We are not liable for any business losses, data loss, or damages arising from use of this app. Users should maintain their own backup systems.")
                    
                    Text("Changes to Terms")
                        .font(.headline)
                    Text("We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of modified terms.")
                }
            }
            .padding()
        }
        .navigationTitle(t("settings.terms"))
    }
}

struct AddCategoryView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""

    var body: some View {
        NavigationView {
            Form {
                Section(t("cat.categoryDetails")) {
                    TextField(t("cat.categoryNamePlaceholder"), text: $categoryName)
                }
            }
            .navigationTitle(t("cat.addCategory"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t("action.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("action.save")) {
                        let cat = UserCategory(name: categoryName, dateCreated: Date())
                        viewModel.addCategory(cat)
                        dismiss()
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
        }
    }
}
