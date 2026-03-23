// InventoryApp.swift
import SwiftUI
import PDFKit

@main
struct InventoryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Models.swift
import Foundation

struct Business: Identifiable, Codable {
    var id = UUID()
    var name: String
    var dateCreated: Date
}

struct InventoryItem: Identifiable, Codable {
    var id = UUID()
    var businessId: UUID
    var name: String
    var purchasePrice: Double?
    var mrp: Double?
    var sellingPrice: Double?
    var priceUnit: String
    var category: String
    var openingStock: Double
    var currentStock: Double
    var dateAdded: Date
}

struct Transaction: Identifiable, Codable {
    var id = UUID()
    var businessId: UUID
    var itemId: UUID
    var itemName: String
    var itemCategory: String
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

struct Category {
    static let categories = [
        "All Items",
        "Electronics",
        "Furniture",
        "Clothing",
        "Food",
        "Office Supplies",
        "Hardware",
        "Cosmetics",
        "Medicine",
        "Stationery",
        "Other"
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
    @Published var businesses: [Business] = []
    @Published var currentBusinessId: UUID?
    @Published var currentUser: String = "User"
    @Published var userEmail: String = ""
    
    var currentBusiness: Business? {
        guard let id = currentBusinessId else { return businesses.first }
        return businesses.first(where: { $0.id == id })
    }
    
    var currentBusinessItems: [InventoryItem] {
        guard let businessId = currentBusinessId else { return [] }
        return items.filter { $0.businessId == businessId }
    }
    
    var currentBusinessTransactions: [Transaction] {
        guard let businessId = currentBusinessId else { return [] }
        return transactions.filter { $0.businessId == businessId }
    }
    
    init() {
        loadData()
        if businesses.isEmpty {
            let defaultBusiness = Business(name: "JM & Sons", dateCreated: Date())
            businesses.append(defaultBusiness)
            currentBusinessId = defaultBusiness.id
            saveData()
        }
        if items.isEmpty {
            addSampleData()
        }
    }
    
    var totalPurchase: Double {
        currentBusinessTransactions
            .filter { $0.type == .purchase || $0.type == .stockIn }
            .reduce(0) { $0 + $1.totalAmount }
    }
    
    var totalSales: Double {
        currentBusinessTransactions
            .filter { $0.type == .sale || $0.type == .stockOut }
            .reduce(0) { $0 + $1.totalAmount }
    }
    
    var totalProfit: Double {
        totalSales - totalPurchase
    }
    
    func sortedItems(_ items: [InventoryItem], by sortOption: SortOption) -> [InventoryItem] {
        switch sortOption {
        case .nameAsc:
            return items.sorted { $0.name < $1.name }
        case .nameDesc:
            return items.sorted { $0.name > $1.name }
        case .stockLow:
            return items.sorted { $0.currentStock < $1.currentStock }
        case .stockHigh:
            return items.sorted { $0.currentStock > $1.currentStock }
        case .dateNew:
            return items.sorted { $0.dateAdded > $1.dateAdded }
        case .dateOld:
            return items.sorted { $0.dateAdded < $1.dateAdded }
        }
    }
    
    func generatePDF(title: String, content: String) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Inventory Manager",
            kCGPDFContextAuthor: currentUser,
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
    
    func addBusiness(_ business: Business) {
        businesses.append(business)
        saveData()
    }
    
    func deleteBusiness(_ business: Business) {
        businesses.removeAll { $0.id == business.id }
        items.removeAll { $0.businessId == business.id }
        transactions.removeAll { $0.businessId == business.id }
        if currentBusinessId == business.id {
            currentBusinessId = businesses.first?.id
        }
        saveData()
    }
    
    func switchBusiness(to businessId: UUID) {
        currentBusinessId = businessId
        saveData()
    }
    
    func addItem(_ item: InventoryItem) {
        items.append(item)
        saveData()
    }
    
    func updateItem(_ item: InventoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveData()
        }
    }
    
    func deleteItem(_ item: InventoryItem) {
        items.removeAll { $0.id == item.id }
        transactions.removeAll { $0.itemId == item.id }
        saveData()
    }
    
    func addTransaction(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
        saveData()
    }
    
    func stockIn(for item: InventoryItem, quantity: Double, pricePerUnit: Double?) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].currentStock += quantity
            
            let totalAmount = (pricePerUnit ?? 0) * quantity
            let transaction = Transaction(
                businessId: item.businessId,
                itemId: item.id,
                itemName: item.name,
                itemCategory: item.category,
                type: .stockIn,
                quantity: quantity,
                pricePerUnit: pricePerUnit,
                totalAmount: totalAmount,
                date: Date()
            )
            addTransaction(transaction)
            saveData()
        }
    }
    
    func stockOut(for item: InventoryItem, quantity: Double, pricePerUnit: Double?) -> Bool {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            if items[index].currentStock - quantity < 0 {
                return false
            }
            
            items[index].currentStock -= quantity
            
            let totalAmount = (pricePerUnit ?? item.sellingPrice ?? 0) * quantity
            let transaction = Transaction(
                businessId: item.businessId,
                itemId: item.id,
                itemName: item.name,
                itemCategory: item.category,
                type: .stockOut,
                quantity: quantity,
                pricePerUnit: pricePerUnit,
                totalAmount: totalAmount,
                date: Date()
            )
            addTransaction(transaction)
            saveData()
            return true
        }
        return false
    }
    
    func getStockIn(for item: InventoryItem) -> Double {
        currentBusinessTransactions
            .filter { $0.itemId == item.id && ($0.type == .stockIn || $0.type == .purchase) }
            .reduce(0) { $0 + $1.quantity }
    }
    
    func getStockOut(for item: InventoryItem) -> Double {
        currentBusinessTransactions
            .filter { $0.itemId == item.id && ($0.type == .stockOut || $0.type == .sale) }
            .reduce(0) { $0 + $1.quantity }
    }
    
    func logout() {
        currentUser = "User"
        userEmail = ""
        saveData()
    }
    
    func saveData() {
        if let itemsData = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(itemsData, forKey: "inventoryItems")
        }
        if let transactionsData = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(transactionsData, forKey: "transactions")
        }
        if let businessesData = try? JSONEncoder().encode(businesses) {
            UserDefaults.standard.set(businessesData, forKey: "businesses")
        }
        if let currentBusinessId = currentBusinessId {
            UserDefaults.standard.set(currentBusinessId.uuidString, forKey: "currentBusinessId")
        }
        UserDefaults.standard.set(currentUser, forKey: "currentUser")
        UserDefaults.standard.set(userEmail, forKey: "userEmail")
    }
    
    private func loadData() {
        if let itemsData = UserDefaults.standard.data(forKey: "inventoryItems"),
           let decoded = try? JSONDecoder().decode([InventoryItem].self, from: itemsData) {
            items = decoded
        }
        if let transactionsData = UserDefaults.standard.data(forKey: "transactions"),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: transactionsData) {
            transactions = decoded
        }
        if let businessesData = UserDefaults.standard.data(forKey: "businesses"),
           let decoded = try? JSONDecoder().decode([Business].self, from: businessesData) {
            businesses = decoded
        }
        if let businessIdString = UserDefaults.standard.string(forKey: "currentBusinessId"),
           let businessId = UUID(uuidString: businessIdString) {
            currentBusinessId = businessId
        }
        if let user = UserDefaults.standard.string(forKey: "currentUser") {
            currentUser = user
        }
        if let email = UserDefaults.standard.string(forKey: "userEmail") {
            userEmail = email
        }
    }
    
    private func addSampleData() {
        guard let businessId = currentBusinessId else { return }
        
        let laptop = InventoryItem(
            businessId: businessId,
            name: "36 no biri, D1",
            purchasePrice: 450,
            mrp: 500,
            sellingPrice: 480,
            priceUnit: "cartoon",
            category: "Electronics",
            openingStock: 2.0,
            currentStock: 2.0,
            dateAdded: Date()
        )
        
        let chair = InventoryItem(
            businessId: businessId,
            name: "5 Bhai Sabun",
            purchasePrice: 80,
            mrp: 100,
            sellingPrice: 95,
            priceUnit: "Bundle",
            category: "Furniture",
            openingStock: 0,
            currentStock: 0,
            dateAdded: Date()
        )
        
        items = [laptop, chair]
        saveData()
    }
}

// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @State private var selectedTab = 1
    
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
        .background(Color.gray.opacity(0.05))
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
    @State private var showingBusinessPicker = false
    @State private var selectedCategory = "All Items"
    @State private var searchText = ""
    @State private var sortOption: SortOption = .nameAsc
    
    let periods = ["Daily", "Weekly", "Monthly", "Yearly"]
    
    var filteredItems: [InventoryItem] {
        var items = viewModel.currentBusinessItems
        
        if selectedCategory != "All Items" {
            items = items.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return viewModel.sortedItems(items, by: sortOption)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        HStack {
                            Button(action: { showingBusinessPicker = true }) {
                                HStack {
                                    Text("Your Business")
                                        .font(.headline)
                                    Image(systemName: "chevron.down")
                                }
                                .foregroundColor(.white)
                            }
                            .sheet(isPresented: $showingBusinessPicker) {
                                BusinessPickerView(viewModel: viewModel)
                            }
                            
                            Spacer()
                            
                            Button(action: { selectedTab = 4 }) {
                                Text("Help")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        
                        HStack {
                            Text(viewModel.currentBusiness?.name ?? "No Business")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(20)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Button(action: {
                                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Text(selectedDate, style: .date)
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            }) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.2), radius: 5)
                        .padding(.horizontal)
                        
                        HStack {
                            Spacer()
                            Menu {
                                ForEach(periods, id: \.self) { period in
                                    Button(period) {
                                        selectedPeriod = period
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedPeriod)
                                    Image(systemName: "chevron.down")
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(color: .gray.opacity(0.2), radius: 3)
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Total Profit")
                                    .font(.headline)
                                Spacer()
                                Text("₹ (+)\(String(format: "%.2f", viewModel.totalProfit))")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Total Purchase")
                                Spacer()
                                Text("₹ \(String(format: "%.2f", viewModel.totalPurchase))")
                                    .foregroundColor(.red)
                            }
                            
                            HStack {
                                Text("Total Sales")
                                Spacer()
                                Text("₹ \(String(format: "%.2f", viewModel.totalSales))")
                                    .foregroundColor(.green)
                            }
                            
                            Divider()
                            
                            HStack {
                                NavigationLink(destination: ReportsView(viewModel: viewModel)) {
                                    Text("Reports >")
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                                
                                NavigationLink(destination: DetailedSummaryView(viewModel: viewModel)) {
                                    Text("Detailed Summary >")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding()
                        .background(Color.mint.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Menu {
                                    ForEach(Category.categories, id: \.self) { category in
                                        Button(category) {
                                            selectedCategory = category
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedCategory)
                                            .font(.headline)
                                        Image(systemName: "chevron.down")
                                    }
                                    .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                Menu {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Button(option.rawValue) {
                                            sortOption = option
                                        }
                                    }
                                } label: {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.title3)
                                }
                                
                                NavigationLink(destination: ReportsView(viewModel: viewModel)) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.title3)
                                }
                            }
                            .padding()
                            
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                TextField("Search item name", text: $searchText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            
                            ForEach(filteredItems) { item in
                                ItemStockCard(item: item, viewModel: viewModel)
                            }
                        }
                        .background(Color.white)
                        
                        Spacer(minLength: 100)
                    }
                }
                .background(Color.gray.opacity(0.05))
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(destination: AddItemView(viewModel: viewModel)) {
                            Image(systemName: "plus")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct BusinessPickerView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.businesses) { business in
                    Button(action: {
                        viewModel.switchBusiness(to: business.id)
                        dismiss()
                    }) {
                        HStack {
                            Text(business.name)
                            Spacer()
                            if business.id == viewModel.currentBusinessId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Switch Business")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
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
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.2), radius: 3)
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
            return viewModel.currentBusinessTransactions
        }
        return viewModel.currentBusinessTransactions.filter {
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
                                    HStack {
                                        Text(transaction.type.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if !transaction.itemCategory.isEmpty {
                                            Text("•")
                                                .foregroundColor(.secondary)
                                            Text(transaction.itemCategory)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
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
    
    var body: some View {
        List {
            Section("Sales Reports") {
                ReportRow(title: "Daily Sales", icon: "chart.line.uptrend.xyaxis", viewModel: viewModel, reportType: "Daily Sales")
                ReportRow(title: "Monthly Sales", icon: "chart.bar", viewModel: viewModel, reportType: "Monthly Sales")
                ReportRow(title: "Yearly Sales", icon: "chart.pie", viewModel: viewModel, reportType: "Yearly Sales")
            }
            
            Section("Stock Reports") {
                ReportRow(title: "Stock Summary", icon: "cube.box", viewModel: viewModel, reportType: "Stock Summary")
                ReportRow(title: "Low Stock Items", icon: "exclamationmark.triangle", viewModel: viewModel, reportType: "Low Stock")
            }
            
            Section("Financial Reports") {
                ReportRow(title: "Profit & Loss", icon: "dollarsign.circle", viewModel: viewModel, reportType: "Profit & Loss")
            }
        }
        .navigationTitle("Reports")
    }
}

struct ReportRow: View {
    let title: String
    let icon: String
    @ObservedObject var viewModel: InventoryViewModel
    let reportType: String
    @State private var showingShareSheet = false
    @State private var pdfURL: URL?
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Button(action: {
                generatePDF()
            }) {
                Image(systemName: "arrow.down.doc")
                    .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = pdfURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    func generatePDF() {
        var content = ""
        
        switch reportType {
        case "Daily Sales":
            content = generateSalesReport()
        case "Monthly Sales":
            content = generateSalesReport()
        case "Yearly Sales":
            content = generateSalesReport()
        case "Stock Summary":
            content = generateStockSummary()
        case "Low Stock":
            content = generateLowStockReport()
        case "Profit & Loss":
            content = generateProfitLossReport()
        default:
            content = "Report data"
        }
        
        pdfURL = viewModel.generatePDF(title: reportType, content: content)
        showingShareSheet = true
    }
    
    func generateSalesReport() -> String {
        var report = "Business: \(viewModel.currentBusiness?.name ?? "Unknown")\n\n"
        report += "Total Sales: ₹\(String(format: "%.2f", viewModel.totalSales))\n\n"
        report += "Transactions:\n\n"
        
        for transaction in viewModel.currentBusinessTransactions.filter({ $0.type == .sale || $0.type == .stockOut }).prefix(50) {
            report += "\(transaction.itemName)\n"
            report += "Amount: ₹\(String(format: "%.2f", transaction.totalAmount))\n"
            report += "Quantity: \(String(format: "%.1f", transaction.quantity))\n"
            report += "Date: \(transaction.date.formatted())\n\n"
        }
        
        return report
    }
    
    func generateStockSummary() -> String {
        var report = "Business: \(viewModel.currentBusiness?.name ?? "Unknown")\n\n"
        report += "Total Items: \(viewModel.currentBusinessItems.count)\n\n"
        report += "Items:\n\n"
        
        for item in viewModel.currentBusinessItems {
            report += "\(item.name)\n"
            report += "Category: \(item.category)\n"
            report += "Stock: \(String(format: "%.1f", item.currentStock)) \(item.priceUnit)\n"
            if let price = item.sellingPrice {
                report += "Price: ₹\(String(format: "%.2f", price))\n"
            }
            report += "\n"
        }
        
        return report
    }
    
    func generateLowStockReport() -> String {
        var report = "Business: \(viewModel.currentBusiness?.name ?? "Unknown")\n\n"
        report += "Low Stock Items:\n\n"
        
        let lowStockItems = viewModel.currentBusinessItems.filter { $0.currentStock <= 5 }
        
        for item in lowStockItems {
            report += "\(item.name)\n"
            report += "Stock: \(String(format: "%.1f", item.currentStock)) \(item.priceUnit)\n"
            report += "Category: \(item.category)\n\n"
        }
        
        if lowStockItems.isEmpty {
            report += "No low stock items found."
        }
        
        return report
    }
    
    func generateProfitLossReport() -> String {
        var report = "Business: \(viewModel.currentBusiness?.name ?? "Unknown")\n\n"
        report += "Profit & Loss Statement\n\n"
        report += "Total Sales: ₹\(String(format: "%.2f", viewModel.totalSales))\n"
        report += "Total Purchases: ₹\(String(format: "%.2f", viewModel.totalPurchase))\n"
        report += "Net Profit/Loss: ₹\(String(format: "%.2f", viewModel.totalProfit))\n"
        
        return report
    }
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
                    Text("\(viewModel.currentBusinessItems.count)")
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
                ForEach(viewModel.currentBusinessTransactions.prefix(20)) { transaction in
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
        viewModel.currentBusinessItems.reduce(0) { total, item in
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
        var items = viewModel.currentBusinessItems
        
        if selectedCategory != "All Items" {
            items = items.filter { $0.category == selectedCategory }
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
                    HStack(spacing: 12) {
                        ForEach(Category.categories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.05))
                
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
                    if !item.category.isEmpty {
                        Text(item.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
    @State private var category = ""
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
                
                Section("Additional Info") {
                    Picker("Category", selection: $category) {
                        Text("Select Category").tag("")
                        ForEach(Category.categories.filter { $0 != "All Items" }, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
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
        guard let businessId = viewModel.currentBusinessId else { return }
        
        let stock = Double(openingStock) ?? 0
        let item = InventoryItem(
            businessId: businessId,
            name: name,
            purchasePrice: Double(purchasePrice),
            mrp: Double(mrp),
            sellingPrice: Double(sellingPrice),
            priceUnit: priceUnit,
            category: category,
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
                if !item.category.isEmpty {
                    DetailRow(label: "Category", value: item.category)
                }
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
    @State private var category: String
    
    init(viewModel: InventoryViewModel, item: InventoryItem) {
        self.viewModel = viewModel
        self.item = item
        _name = State(initialValue: item.name)
        _purchasePrice = State(initialValue: item.purchasePrice != nil ? String(item.purchasePrice!) : "")
        _mrp = State(initialValue: item.mrp != nil ? String(item.mrp!) : "")
        _sellingPrice = State(initialValue: item.sellingPrice != nil ? String(item.sellingPrice!) : "")
        _priceUnit = State(initialValue: item.priceUnit)
        _category = State(initialValue: item.category)
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
                
                Section("Additional Info") {
                    Picker("Category", selection: $category) {
                        Text("Select Category").tag("")
                        ForEach(Category.categories.filter { $0 != "All Items" }, id: \.self) { cat in
                            Text(cat).tag(cat)
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
        updatedItem.category = category
        
        viewModel.updateItem(updatedItem)
        dismiss()
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showingAddBusiness = false
    @State private var showingLogoutAlert = false
    @State private var showingLoginSheet = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if viewModel.userEmail.isEmpty {
                        Button(action: { showingLoginSheet = true }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.blue)
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
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(viewModel.currentUser)
                                    .font(.headline)
                                Text(viewModel.userEmail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Businesses") {
                    ForEach(viewModel.businesses) { business in
                        HStack {
                            Text(business.name)
                            Spacer()
                            if business.id == viewModel.currentBusinessId {
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .onDelete(perform: deleteBusiness)
                    
                    Button(action: { showingAddBusiness = true }) {
                        Label("Add Business", systemImage: "plus.circle.fill")
                    }
                }
                
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
                    
                    Link(destination: URL(string: "mailto:support@inventoryapp.com")!) {
                        Label("Contact Us", systemImage: "envelope")
                    }
                }
                
                Section {
                    Button(action: { showingLogoutAlert = true }) {
                        Label("Logout", systemImage: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddBusiness) {
                AddBusinessView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingLoginSheet) {
                GoogleSignInView(viewModel: viewModel)
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    viewModel.logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
    
    func deleteBusiness(at offsets: IndexSet) {
        for index in offsets {
            let business = viewModel.businesses[index]
            if viewModel.businesses.count > 1 {
                viewModel.deleteBusiness(business)
            }
        }
    }
}

struct GoogleSignInView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var name = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Sign in to sync your data")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Note: Google Sign-In requires additional setup with Firebase/Google Cloud Platform. For now, you can enter your details manually.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                VStack(spacing: 16) {
                    TextField("Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    viewModel.currentUser = name.isEmpty ? "User" : name
                    viewModel.userEmail = email
                    viewModel.saveData()
                    dismiss()
                }) {
                    Text("Sign In")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(email.isEmpty)
                
                Text("To integrate real Google Sign-In:\n1. Set up Firebase project\n2. Add GoogleSignIn SDK\n3. Configure OAuth credentials")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
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

struct AddBusinessView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var businessName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Business Details") {
                    TextField("Business Name", text: $businessName)
                }
            }
            .navigationTitle("Add Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let business = Business(name: businessName, dateCreated: Date())
                        viewModel.addBusiness(business)
                        dismiss()
                    }
                    .disabled(businessName.isEmpty)
                }
            }
        }
    }
}
