import SwiftUI
import PDFKit
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct InventoryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
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
        "KG", "Bora", "ML", "Litre",
        "MM", "CM", "Meter", "KM",
        "Inch", "Feet", "Sq.Inch", "Sq.Ft",
        "Sq.Meter", "Dozen", "Bundle", "Pouch",
        "Carat", "Gross", "Minute", "Hour",
        "Day", "Month", "Year", "Service",
        "Work", "Pound", "Pair", "Quintal",
        "Ton", "Plate", "Person", "Ratti",
        "Trolley", "Truck", "15 litre", "30 kg",
        "50 kg", "Bag", "Bori", "cartoon",
        "Danda", "Dibba", "Jar", "jhaal",
        "katta", "Katta", "katti", "kg",
        "ladi", "panni", "Peepa", "Thaila",
        "Thaila 25", "Tin", "Piece"
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
        var data: [String: Any] = ["businessName": businessName]
        if let id = currentCategoryId { data["currentCategoryId"] = id.uuidString }
        userRef().collection("settings").document("current").setData(data, merge: true)
    }

    func updateBusinessName(_ name: String) {
        businessName = name
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

    func generatePDF(title: String, content: String) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Inventory Manager",
            kCGPDFContextAuthor: "User",
            kCGPDFContextTitle: title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont]
            let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]
            title.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
            let textRect = CGRect(x: 50, y: 100, width: pageWidth - 100, height: pageHeight - 150)
            content.draw(in: textRect, withAttributes: bodyAttributes)
        }

        let fileName = "\(title.replacingOccurrences(of: " ", with: "_")).pdf"
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
            let totalAmount = (pricePerUnit ?? item.sellingPrice ?? 0) * quantity
            let transaction = Transaction(
                categoryId: item.categoryId,
                itemId: item.id,
                itemName: item.name,
                type: .stockOut,
                quantity: quantity,
                pricePerUnit: pricePerUnit,
                totalAmount: totalAmount,
                date: Date()
            )
            addTransaction(transaction)
            guard !userId.isEmpty else { return true }
            if let data = encodeModel(items[index]) {
                userRef().collection("items").document(item.id.uuidString).setData(data)
            }
            return true
        }
        return false
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

struct ContentView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
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
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            DashboardView(viewModel: viewModel, selectedTab: $selectedTab)
                .tabItem {
                    Label("Stock", systemImage: "arrow.left.arrow.right")
                }
                .tag(1)

            InventoryListView(viewModel: viewModel)
                .tabItem {
                    Label("Items", systemImage: "square.grid.2x2.fill")
                }
                .tag(2)

            TransactionsView(viewModel: viewModel)
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }
                .tag(3)

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(.indigo)
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
                VStack(spacing: 24) {
                    // App Logo
                    VStack(spacing: 16) {
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Inventory Manager")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Manage your stock effortlessly")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        FeatureCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Real-time Tracking",
                            description: "Monitor your inventory levels in real-time with instant updates"
                        )
                        
                        FeatureCard(
                            icon: "building.2",
                            title: "Multi-Business Support",
                            description: "Manage multiple businesses from a single account"
                        )
                        
                        FeatureCard(
                            icon: "doc.text.fill",
                            title: "Detailed Reports",
                            description: "Generate comprehensive reports and export to PDF"
                        )
                        
                        FeatureCard(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Transaction History",
                            description: "Keep track of all stock movements with detailed history"
                        )
                        
                        FeatureCard(
                            icon: "square.grid.2x2",
                            title: "Category Management",
                            description: "Organize items by categories for easy access"
                        )
                        
                        FeatureCard(
                            icon: "lock.shield",
                            title: "Secure & Private",
                            description: "All your data stays on your device, completely private"
                        )
                    }
                    
                    // Quick Start
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Start Guide")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            QuickStartStep(number: "1", text: "Add your business in Settings")
                            QuickStartStep(number: "2", text: "Create items in the Items tab")
                            QuickStartStep(number: "3", text: "Set opening stock for each item")
                            QuickStartStep(number: "4", text: "Track stock in/out from Stock tab")
                            QuickStartStep(number: "5", text: "View reports and insights")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Welcome")
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
                .foregroundColor(.blue)
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

struct QuickStartStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @Binding var selectedTab: Int
    @State private var selectedDate = Date()
    @State private var selectedPeriod = "Daily"
    @State private var selectedCategoryId: UUID? = nil
    @State private var searchText = ""
    @State private var sortOption: SortOption = .nameAsc

    let periods = ["Daily", "Weekly", "Monthly", "Yearly"]

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

    var totalPurchaseFiltered: Double {
        selectedTransactions
            .filter { $0.type == .purchase || $0.type == .stockIn }
            .reduce(0) { $0 + $1.totalAmount }
    }

    var totalSalesFiltered: Double {
        selectedTransactions
            .filter { $0.type == .sale || $0.type == .stockOut }
            .reduce(0) { $0 + $1.totalAmount }
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
                                colors: [Color.indigo, Color.blue],
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
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(viewModel.businessName.isEmpty ? "My Business" : viewModel.businessName)
                                            .font(.title2.bold())
                                            .foregroundColor(.white)
                                        Text("Stock Dashboard")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.75))
                                    }
                                    Spacer()
                                    Button(action: { selectedTab = 4 }) {
                                        Image(systemName: "questionmark.circle")
                                            .font(.title3)
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                        }

                        VStack(spacing: 12) {
                            // Category chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    CategoryFilterChip(
                                        name: "All Items",
                                        count: viewModel.items.count,
                                        isSelected: selectedCategoryId == nil
                                    ) { selectedCategoryId = nil }

                                    ForEach(viewModel.categories) { cat in
                                        CategoryFilterChip(
                                            name: cat.name,
                                            count: viewModel.items.filter { $0.categoryId == cat.id }.count,
                                            isSelected: selectedCategoryId == cat.id
                                        ) { selectedCategoryId = cat.id }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }

                            // Date & period row
                            HStack {
                                Button(action: {
                                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                                }) {
                                    Image(systemName: "chevron.left").foregroundColor(.primary)
                                }
                                Spacer()
                                Text(selectedDate, style: .date).font(.headline)
                                Spacer()
                                Button(action: {
                                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                                }) {
                                    Image(systemName: "chevron.right").foregroundColor(.primary)
                                }
                                Menu {
                                    ForEach(periods, id: \.self) { p in Button(p) { selectedPeriod = p } }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(selectedPeriod).font(.subheadline)
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
                                    Text("Total Profit")
                                        .font(.headline)
                                    Spacer()
                                    Text("₹ \(String(format: "%.2f", totalSalesFiltered - totalPurchaseFiltered))")
                                        .font(.headline)
                                        .foregroundColor(totalSalesFiltered - totalPurchaseFiltered >= 0 ? .green : .red)
                                }
                                Divider()
                                HStack {
                                    Text("Total Purchase").foregroundColor(.secondary)
                                    Spacer()
                                    Text("₹ \(String(format: "%.2f", totalPurchaseFiltered))").foregroundColor(.red)
                                }
                                HStack {
                                    Text("Total Sales").foregroundColor(.secondary)
                                    Spacer()
                                    Text("₹ \(String(format: "%.2f", totalSalesFiltered))").foregroundColor(.green)
                                }
                                Divider()
                                HStack {
                                    NavigationLink(destination: ReportsView(viewModel: viewModel)) {
                                        Text("Reports →").foregroundColor(.indigo)
                                    }
                                    Spacer()
                                    NavigationLink(destination: DetailedSummaryView(viewModel: viewModel)) {
                                        Text("Detailed Summary →").foregroundColor(.indigo)
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
                                        TextField("Search items", text: $searchText)
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
                                            .foregroundColor(.indigo)
                                    }

                                    NavigationLink(destination: ReportsView(viewModel: viewModel)) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.title3)
                                            .foregroundColor(.indigo)
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
                NavigationLink(destination: AddItemView(viewModel: viewModel)) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(18)
                        .background(
                            LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Circle())
                        .shadow(color: .indigo.opacity(0.4), radius: 8, y: 4)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
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
            .background(isSelected ? Color.indigo : Color(.tertiarySystemFill))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct ItemStockCard: View {
    let item: InventoryItem
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showingStockIn = false
    @State private var showingStockOut = false
    @State private var showingItemDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text("Updated recently")
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
                    Text("Total Stock In")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", viewModel.getStockIn(for: item))) \(item.priceUnit)")
                        .foregroundColor(.brown)
                }
                
                VStack(alignment: .leading) {
                    Text("Opening Stock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", item.openingStock)) \(item.priceUnit)")
                }
            }
            
            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text("Total Stock Out")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", viewModel.getStockOut(for: item))) \(item.priceUnit)")
                        .foregroundColor(.brown)
                }
                
                VStack(alignment: .leading) {
                    Text("Remaining Stock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", item.currentStock)) \(item.priceUnit)")
                }
            }
            
            HStack(spacing: 12) {
                Button(action: { showingStockIn = true }) {
                    Text("In")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red, lineWidth: 1)
                        )
                }
                
                Button(action: { showingStockOut = true }) {
                    Text("Out")
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 1)
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
    }
}

struct TransactionsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var searchText = ""
    @State private var selectedTransaction: Transaction?
    
    var filteredTransactions: [Transaction] {
        if searchText.isEmpty {
            return viewModel.currentCategoryTransactions
        }
        return viewModel.currentCategoryTransactions.filter {
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
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: transaction.type == .stockIn || transaction.type == .purchase ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                    .foregroundColor(transaction.type == .stockIn || transaction.type == .purchase ? .green : .red)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.itemName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(transaction.type.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("₹ \(String(format: "%.2f", transaction.totalAmount))")
                                        .font(.headline)
                                        .foregroundColor(transaction.type == .stockIn || transaction.type == .purchase ? .green : .red)
                                    Text("\(String(format: "%.1f", transaction.quantity)) units")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Text(transaction.date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(transaction.date, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if let price = transaction.pricePerUnit {
                                    Text("@ ₹\(String(format: "%.2f", price))/unit")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search transactions")
            .navigationTitle("Transactions")
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

struct ReportsView: View {
    @ObservedObject var viewModel: InventoryViewModel

    let reports: [(title: String, icon: String, type: String)] = [
        ("Daily Sales", "chart.line.uptrend.xyaxis", "Daily Sales"),
        ("Monthly Sales", "chart.bar", "Monthly Sales"),
        ("Yearly Sales", "chart.pie", "Yearly Sales"),
        ("Stock Summary", "cube.box", "Stock Summary"),
        ("Low Stock Items", "exclamationmark.triangle", "Low Stock"),
        ("Profit & Loss", "dollarsign.circle", "Profit & Loss")
    ]

    var body: some View {
        List {
            Section("Sales Reports") {
                ForEach(reports.prefix(3), id: \.type) { r in
                    NavigationLink(destination: ReportDetailView(viewModel: viewModel, reportType: r.type)) {
                        Label(r.title, systemImage: r.icon)
                    }
                }
            }
            Section("Stock Reports") {
                ForEach(reports.dropFirst(3).prefix(2), id: \.type) { r in
                    NavigationLink(destination: ReportDetailView(viewModel: viewModel, reportType: r.type)) {
                        Label(r.title, systemImage: r.icon)
                    }
                }
            }
            Section("Financial Reports") {
                NavigationLink(destination: ReportDetailView(viewModel: viewModel, reportType: "Profit & Loss")) {
                    Label("Profit & Loss", systemImage: "dollarsign.circle")
                }
            }
        }
        .navigationTitle("Reports")
    }
}

struct ReportDetailView: View {
    @ObservedObject var viewModel: InventoryViewModel
    let reportType: String
    @State private var showingShareSheet = false
    @State private var pdfURL: URL?

    var reportContent: String {
        switch reportType {
        case "Daily Sales", "Monthly Sales", "Yearly Sales": return generateSalesReport()
        case "Stock Summary": return generateStockSummary()
        case "Low Stock": return generateLowStockReport()
        case "Profit & Loss": return generateProfitLossReport()
        default: return ""
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 80)
                        .overlay(
                            Text(reportType)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .padding()
                            , alignment: .bottomLeading
                        )

                    // Content
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(reportContent.components(separatedBy: "\n\n"), id: \.self) { block in
                            if !block.trimmingCharacters(in: .whitespaces).isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(block.components(separatedBy: "\n"), id: \.self) { line in
                                        if !line.isEmpty {
                                            if line.hasSuffix(":") || (!line.contains(":") && !line.contains("₹") && !line.contains("Date:") && line.count < 40) {
                                                Text(line)
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.primary)
                                            } else {
                                                Text(line)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
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
                    .padding(.bottom, 80)
                }
            }
            .background(Color(.secondarySystemBackground))

            // Export button
            Button(action: {
                pdfURL = viewModel.generatePDF(title: reportType, content: reportContent)
                showingShareSheet = true
            }) {
                Label("Export PDF", systemImage: "arrow.up.doc")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.indigo, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
                    .shadow(color: .indigo.opacity(0.35), radius: 6, y: 3)
            }
            .padding()
        }
        .navigationTitle(reportType)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = pdfURL { ShareSheet(items: [url]) }
        }
    }

    func generateSalesReport() -> String {
        var report = "Business: \(viewModel.businessName)\n\n"
        report += "Total Sales: ₹\(String(format: "%.2f", viewModel.totalSales))\n\n"
        report += "Transactions:\n\n"
        for t in viewModel.currentCategoryTransactions.filter({ $0.type == .sale || $0.type == .stockOut }).prefix(50) {
            report += "\(t.itemName)\nAmount: ₹\(String(format: "%.2f", t.totalAmount))\nQty: \(String(format: "%.1f", t.quantity))\nDate: \(t.date.formatted())\n\n"
        }
        return report
    }

    func generateStockSummary() -> String {
        var report = "Business: \(viewModel.businessName)\n\nTotal Items: \(viewModel.currentCategoryItems.count)\n\nItems:\n\n"
        for item in viewModel.currentCategoryItems {
            report += "\(item.name)\nStock: \(String(format: "%.1f", item.currentStock)) \(item.priceUnit)\n"
            if let p = item.sellingPrice { report += "Price: ₹\(String(format: "%.2f", p))\n" }
            report += "\n"
        }
        return report
    }

    func generateLowStockReport() -> String {
        var report = "Business: \(viewModel.businessName)\n\nLow Stock Items:\n\n"
        let low = viewModel.currentCategoryItems.filter { $0.currentStock <= 5 }
        for item in low {
            report += "\(item.name)\nStock: \(String(format: "%.1f", item.currentStock)) \(item.priceUnit)\n\n"
        }
        if low.isEmpty { report += "No low stock items found." }
        return report
    }

    func generateProfitLossReport() -> String {
        "Business: \(viewModel.businessName)\n\nProfit & Loss Statement\n\nTotal Sales: ₹\(String(format: "%.2f", viewModel.totalSales))\nTotal Purchases: ₹\(String(format: "%.2f", viewModel.totalPurchase))\nNet Profit/Loss: ₹\(String(format: "%.2f", viewModel.totalProfit))"
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

struct DetailedSummaryView: View {
    @ObservedObject var viewModel: InventoryViewModel

    var body: some View {
        List {
            Section("Summary") {
                HStack {
                    Text("Total Items")
                    Spacer()
                    Text("\(viewModel.currentCategoryItems.count)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Total Stock Value")
                    Spacer()
                    Text("₹ \(String(format: "%.2f", calculateTotalValue()))")
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Total Purchase")
                    Spacer()
                    Text("₹ \(String(format: "%.2f", viewModel.totalPurchase))")
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }

                HStack {
                    Text("Total Sales")
                    Spacer()
                    Text("₹ \(String(format: "%.2f", viewModel.totalSales))")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                HStack {
                    Text("Net Profit")
                    Spacer()
                    Text("₹ \(String(format: "%.2f", viewModel.totalProfit))")
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.totalProfit >= 0 ? .green : .red)
                }
            }

            Section("Recent Transactions") {
                ForEach(viewModel.currentCategoryTransactions.prefix(20)) { transaction in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(transaction.itemName)
                                .font(.subheadline)
                            Text(transaction.type.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("₹ \(String(format: "%.2f", transaction.totalAmount))")
                                .fontWeight(.semibold)
                            Text("\(String(format: "%.1f", transaction.quantity)) units")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Detailed Summary")
    }

    func calculateTotalValue() -> Double {
        viewModel.currentCategoryItems.reduce(0) { total, item in
            total + (item.currentStock * (item.sellingPrice ?? 0))
        }
    }
}

struct InventoryListView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var selectedCategory = "All Items"

    var filteredItems: [InventoryItem] {
        var items = viewModel.currentCategoryItems
        if selectedCategory != "All Items" {
            if let cat = viewModel.categories.first(where: { $0.name == selectedCategory }) {
                items = viewModel.items.filter { $0.categoryId == cat.id }
            }
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
                            name: "All Items",
                            count: viewModel.currentCategoryItems.count,
                            isSelected: selectedCategory == "All Items"
                        ) { selectedCategory = "All Items" }

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
                .searchable(text: $searchText, prompt: "Search items")
            }
            .navigationTitle("Items")
            .toolbar {
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(viewModel: viewModel)
            }
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
                    Text("\(String(format: "%.1f", item.currentStock)) \(item.priceUnit)")
                        .font(.headline)
                    if let price = item.sellingPrice {
                        Text("₹\(String(format: "%.2f", price))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Stock In")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", viewModel.getStockIn(for: item)))")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading) {
                    Text("Stock Out")
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
    @State private var sellingPrice = ""
    @State private var priceUnit = "Piece"
    @State private var openingStock = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Item Name *", text: $name)
                }

                Section("Pricing") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Purchase Price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MRP (Maximum Retail Price)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $mrp)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selling Price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $sellingPrice)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Price Unit", selection: $priceUnit) {
                        ForEach(PriceUnit.units, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                }

                Section("Stock") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Opening Stock *")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0", text: $openingStock)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    var isValid: Bool {
        !name.isEmpty && Double(openingStock) != nil
    }

    func saveItem() {
        guard let categoryId = viewModel.currentCategoryId else { return }
        let stock = Double(openingStock) ?? 0
        let item = InventoryItem(
            categoryId: categoryId,
            name: name,
            purchasePrice: Double(purchasePrice),
            mrp: Double(mrp),
            sellingPrice: Double(sellingPrice),
            priceUnit: priceUnit,
            openingStock: stock,
            currentStock: stock,
            dateAdded: Date()
        )
        viewModel.addItem(item)
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
    
    var body: some View {
        List {
            Section("Item Information") {
                DetailRow(label: "Name", value: item.name)
                if let price = item.purchasePrice {
                    DetailRow(label: "Purchase Price", value: "₹\(String(format: "%.2f", price))")
                }
                if let price = item.mrp {
                    DetailRow(label: "MRP", value: "₹\(String(format: "%.2f", price))")
                }
                if let price = item.sellingPrice {
                    DetailRow(label: "Selling Price", value: "₹\(String(format: "%.2f", price))")
                }
                DetailRow(label: "Price Unit", value: item.priceUnit)
                DetailRow(label: "Opening Stock", value: "\(String(format: "%.1f", item.openingStock))")
                DetailRow(label: "Current Stock", value: "\(String(format: "%.1f", item.currentStock))")
            }
            
            Section("Stock Movements") {
                DetailRow(label: "Total Stock In", value: "\(String(format: "%.1f", viewModel.getStockIn(for: item)))")
                DetailRow(label: "Total Stock Out", value: "\(String(format: "%.1f", viewModel.getStockOut(for: item)))")
            }
            
            Section {
                Button(action: { showingStockIn = true }) {
                    Label("Stock In", systemImage: "arrow.down.circle")
                }
                
                Button(action: { showingStockOut = true }) {
                    Label("Stock Out", systemImage: "arrow.up.circle")
                }
                
                Button(action: { showingEdit = true }) {
                    Label("Edit Item", systemImage: "pencil")
                }
                
                Button(action: { showingDeleteAlert = true }) {
                    Label("Delete Item", systemImage: "trash")
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
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteItem(item)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(item.name)'? This action cannot be undone.")
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
                Section(isStockIn ? "Stock In" : "Stock Out") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quantity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0", text: $quantity)
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Price per unit (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $pricePerUnit)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section {
                    Text("Current Stock: \(String(format: "%.1f", item.currentStock)) \(item.priceUnit)")
                        .foregroundColor(.secondary)
                    
                    if !isStockIn, let qty = Double(quantity) {
                        if item.currentStock - qty < 0 {
                            Text("⚠️ Insufficient stock. Available: \(String(format: "%.1f", item.currentStock))")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle(isStockIn ? "Stock In" : "Stock Out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateStock()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
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
                    errorMessage = "Insufficient stock. Cannot go negative."
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

    init(viewModel: InventoryViewModel, item: InventoryItem) {
        self.viewModel = viewModel
        self.item = item
        _name = State(initialValue: item.name)
        _purchasePrice = State(initialValue: item.purchasePrice != nil ? String(item.purchasePrice!) : "")
        _mrp = State(initialValue: item.mrp != nil ? String(item.mrp!) : "")
        _sellingPrice = State(initialValue: item.sellingPrice != nil ? String(item.sellingPrice!) : "")
        _priceUnit = State(initialValue: item.priceUnit)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Item Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Item Name", text: $name)
                    }
                }

                Section("Pricing") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Purchase Price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MRP (Maximum Retail Price)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $mrp)
                            .keyboardType(.decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selling Price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $sellingPrice)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Price Unit", selection: $priceUnit) {
                        ForEach(PriceUnit.units, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
        viewModel.updateItem(updatedItem)
        dismiss()
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingAddCategory = false
    @State private var showingLogoutAlert = false
    @State private var showingLoginSheet = false
    @State private var editingBusinessName = false
    @State private var draftBusinessName = ""

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
                                    .foregroundColor(.indigo)
                                VStack(alignment: .leading) {
                                    Text("Sign in with Google")
                                        .font(.headline)
                                    Text("Sync your data across devices")
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
                                    Image(systemName: "person.circle.fill").font(.largeTitle).foregroundColor(.indigo)
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill").font(.largeTitle).foregroundColor(.indigo)
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
                Section("Business Profile") {
                    if editingBusinessName {
                        HStack {
                            TextField("Business Name", text: $draftBusinessName)
                                .textFieldStyle(.plain)
                            Spacer()
                            Button("Save") {
                                viewModel.updateBusinessName(draftBusinessName)
                                editingBusinessName = false
                            }
                            .foregroundColor(.indigo)
                            .fontWeight(.semibold)
                        }
                    } else {
                        HStack {
                            Text(viewModel.businessName.isEmpty ? "Set business name…" : viewModel.businessName)
                                .foregroundColor(viewModel.businessName.isEmpty ? .secondary : .primary)
                            Spacer()
                            Button("Edit") {
                                draftBusinessName = viewModel.businessName
                                editingBusinessName = true
                            }
                            .foregroundColor(.indigo)
                        }
                    }
                }

                // Categories
                Section("Categories") {
                    ForEach(viewModel.categories) { cat in
                        HStack {
                            Text(cat.name)
                            Spacer()
                            Text("\(viewModel.items.filter { $0.categoryId == cat.id }.count) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if cat.id == viewModel.currentCategoryId {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.indigo).font(.caption)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.switchCategory(to: cat.id) }
                    }
                    .onDelete(perform: deleteCategory)

                    Button(action: { showingAddCategory = true }) {
                        Label("Add Category", systemImage: "plus.circle.fill")
                            .foregroundColor(.indigo)
                    }
                }

                // Support
                Section("Support") {
                    NavigationLink(destination: AppSupportView()) {
                        Label("App Support", systemImage: "questionmark.circle")
                    }
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    NavigationLink(destination: TermsView()) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }

                if authManager.isSignedIn {
                    Section {
                        Button(action: { showingLogoutAlert = true }) {
                            Label("Sign Out", systemImage: "arrow.right.square").foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddCategory) { AddCategoryView(viewModel: viewModel) }
            .sheet(isPresented: $showingLoginSheet) { GoogleSignInView() }
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) { authManager.signOut() }
            } message: {
                Text("Are you sure you want to sign out?")
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
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Welcome to Inventory Manager")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Sign in with your Google account to sync your data across devices")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
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
                        if authManager.isSignedIn {
                            dismiss()
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Sign in with Google")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(authManager.isLoading)
                
                Spacer()
                
                Text("Your data stays private and secure")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                Link(destination: URL(string: "mailto:support@inventoryapp.com")!) {
                    Label("Email: support@inventoryapp.com", systemImage: "envelope")
                }
                
                Text("Phone: +91 1800-123-4567")
                Text("Hours: Mon-Fri 9AM-6PM IST")
            }
        }
        .navigationTitle("App Support")
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("Inventory Manager")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            
            Section("About") {
                Text("Inventory Manager helps you track your business inventory efficiently. Manage stock, track sales and purchases, and generate detailed reports.")
            }
            
            Section("Features") {
                Text("• Multi-business support")
                Text("• Real-time stock tracking")
                Text("• Sales and purchase tracking")
                Text("• Detailed reports and summaries")
                Text("• Category-based filtering")
                Text("• Search functionality")
            }
            
            Section("Developer") {
                Text("Developed with ❤️ for small businesses")
                Text("© 2026 Inventory Manager. All rights reserved.")
            }
        }
        .navigationTitle("About")
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
        .navigationTitle("Privacy Policy")
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
                    Text("Inventory Manager provides tools for tracking business inventory, sales, and purchases. The app is provided 'as is' without warranties of any kind.")
                    
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
        .navigationTitle("Terms of Service")
    }
}

struct AddCategoryView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $categoryName)
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
