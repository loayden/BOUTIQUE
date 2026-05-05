import SwiftUI
import PhotosUI
import UIKit

struct BoutiqueDashboardView: View {
    @State private var products: [Product] = []
    @State private var orders: [Order] = []
    @State private var showAddProduct = false
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Your Products")) {
                    ForEach(products) { product in
                        Text(product.name)
                    }
                    Button("Add Product") {
                        showAddProduct = true
                    }
                }
                Section(header: Text("Orders")) {
                    ForEach(orders) { order in
                        VStack(alignment: .leading) {
                            Text("Order #\(order.id)")
                            Text(order.status.rawValue.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Boutique Dashboard")
            .onAppear(perform: fetchDashboard)
            .sheet(isPresented: $showAddProduct) {
                AddProductView(onAdd: { newProduct in
                    products.append(newProduct)
                })
            }
        }
    }

    private func fetchDashboard() {
        isLoading = true
        Task {
            do {
                async let fetchedProducts = APIService.shared.fetchProducts()
                async let fetchedOrders = APIService.shared.fetchOrders()
                let products = try await fetchedProducts
                let orders = try await fetchedOrders
                await MainActor.run {
                    self.products = products
                    self.orders = orders
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct AddProductView: View {
    var onAdd: (Product) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: ProductCategory = .shirts
    @State private var price = ""
    @State private var imageNames = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoPreview: UIImage?
    @State private var sizes = ""
    @State private var colors = ""
    @State private var summary = ""
    @State private var story = ""
    @State private var composition = ""
    @State private var care = ""
    @State private var delivery = ""
    @State private var returnsPolicy = ""
    @State private var inventory = ""
    @State private var isAvailable = true
    @State private var featured = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Product") {
                    TextField("Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(ProductCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }

                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                }

                Section {
                    TextField("Summary", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Story", text: $story, axis: .vertical)
                        .lineLimit(2...5)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Label("Choose photo from device", systemImage: "photo.badge.plus")
                    }

                    if let selectedPhotoPreview {
                        Image(uiImage: selectedPhotoPreview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    TextField("Extra image names or URLs", text: $imageNames, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Sizes", text: $sizes)
                    TextField("Colors", text: $colors)
                } header: {
                    Text("Catalog")
                } footer: {
                    Text("Separate images, sizes, and colors with commas or new lines.")
                }

                Section("Fulfillment") {
                    TextField("Composition", text: $composition, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Care", text: $care, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Delivery", text: $delivery, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Returns", text: $returnsPolicy, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Status") {
                    TextField("Inventory", text: $inventory)
                        .keyboardType(.numberPad)
                    Toggle("Available", isOn: $isAvailable)
                    Toggle("Featured", isOn: $featured)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        addProduct()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Add Product")
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Add Product")
            .onChange(of: selectedPhotoItem) { _, item in
                loadSelectedPhoto(item)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addProduct() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let uploadedImageName = try await selectedProductImageName()
                let product = try validatedProduct(selectedImageName: uploadedImageName)
                let created = try await APIService.shared.createProduct(product)
                await MainActor.run {
                    onAdd(created)
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func validatedProduct(selectedImageName: String?) throws -> Product {
        let cleanedName = name.boutiqueFormTrimmed
        let cleanedSummary = summary.boutiqueFormTrimmed
        let cleanedStory = story.boutiqueFormTrimmed
        var parsedImages = imageNames.boutiqueFormListValues
        if let selectedImageName {
            parsedImages.insert(selectedImageName, at: 0)
        }
        let parsedSizes = sizes.boutiqueFormListValues
        let parsedColors = colors.boutiqueFormListValues
        let normalizedPrice = price.replacingOccurrences(of: ",", with: ".").boutiqueFormTrimmed
        let parsedPrice = Double(normalizedPrice) ?? .nan
        let parsedInventory = inventory.boutiqueFormTrimmed.isEmpty ? nil : Int(inventory.boutiqueFormTrimmed)

        guard cleanedName.isEmpty == false else {
            throw BoutiqueProductFormError("Product name is required.")
        }
        guard parsedPrice.isFinite, parsedPrice > 0 else {
            throw BoutiqueProductFormError("Enter a price greater than zero.")
        }
        guard cleanedSummary.isEmpty == false else {
            throw BoutiqueProductFormError("Summary is required.")
        }
        guard parsedImages.isEmpty == false else {
            throw BoutiqueProductFormError("Add at least one real image name or URL.")
        }
        guard parsedSizes.isEmpty == false else {
            throw BoutiqueProductFormError("Add at least one size.")
        }
        guard parsedColors.isEmpty == false else {
            throw BoutiqueProductFormError("Add at least one color.")
        }
        if inventory.boutiqueFormTrimmed.isEmpty == false, parsedInventory == nil {
            throw BoutiqueProductFormError("Inventory must be a whole number.")
        }

        return Product(
            id: "boutique-\(UUID().uuidString.lowercased())",
            name: cleanedName,
            category: category,
            price: parsedPrice,
            summary: cleanedSummary,
            story: cleanedStory.isEmpty ? cleanedSummary : cleanedStory,
            imageNames: parsedImages,
            sizes: parsedSizes,
            colors: parsedColors.map { Colorway(name: $0.capitalized, hex: Colorway.hex(for: $0)) },
            composition: composition.boutiqueFormTrimmed,
            care: care.boutiqueFormTrimmed,
            delivery: delivery.boutiqueFormTrimmed,
            returns: returnsPolicy.boutiqueFormTrimmed,
            badge: nil,
            featured: featured,
            inventoryCount: parsedInventory,
            isAvailable: isAvailable
        )
    }

    private func selectedProductImageName() async throws -> String? {
        guard let selectedPhotoData else { return nil }

        if APIConfig.usesEmbeddedStaticBackend {
            return try savePickedProductImage(data: selectedPhotoData)
        }

        return try await APIService.shared.uploadProductImage(
            data: selectedPhotoData,
            fileName: "boutique-product-\(UUID().uuidString.lowercased()).jpg"
        )
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else {
            selectedPhotoData = nil
            selectedPhotoPreview = nil
            return
        }

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        errorMessage = "Could not read the selected photo."
                    }
                    return
                }

                await MainActor.run {
                    selectedPhotoData = data
                    selectedPhotoPreview = UIImage(data: data)
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    selectedPhotoData = nil
                    selectedPhotoPreview = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func savePickedProductImage(data: Data) throws -> String {
        guard let image = UIImage(data: data) else {
            throw BoutiqueProductFormError("The selected photo could not be used.")
        }

        let directory = try Self.productImageDirectory()
        let url = directory.appendingPathComponent("boutique-product-\(UUID().uuidString.lowercased()).jpg")
        guard let jpegData = image.jpegData(compressionQuality: 0.88) else {
            throw BoutiqueProductFormError("The selected photo could not be saved.")
        }

        try jpegData.write(to: url, options: [.atomic])
        return url.path
    }

    private static func productImageDirectory() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL.appendingPathComponent("AurelienProductImages", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct BoutiqueProductFormError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

private extension String {
    var boutiqueFormTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var boutiqueFormListValues: [String] {
        components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.boutiqueFormTrimmed }
            .filter { $0.isEmpty == false }
    }
}
