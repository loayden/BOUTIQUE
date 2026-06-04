import SwiftUI
import Charts
import PhotosUI
import UIKit

private enum AdminTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case products = "Products"
    case orders = "Orders"
    case users = "Users"
    case analytics = "Analytics"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "chart.bar.xaxis"
        case .products: return "cube"
        case .orders: return "bag"
        case .users: return "person.3"
        case .analytics: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct AdminDashboardView: View {
    @Environment(AurelienStore.self) private var store

    @State private var stats: DashboardStats?
    @State private var selectedTab: AdminTab = .overview
    @State private var isLoading = true
    @State private var statusMessage: String?

    var body: some View {
        Group {
            if store.isAdmin {
                adminContent
            } else {
                accessDeniedView
            }
        }
        .background(BrandPalette.background.ignoresSafeArea())
        .navigationTitle("Admin")
        .navigationBarTitleDisplayMode(.large)
        .boutBackButton("Account")
        .task {
            await loadData()
        }
    }

    private var adminContent: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.xl) {
                BrandSectionHeader(
                    eyebrow: "Dashboard",
                    title: "Operations stay clear, compact, and readable on iPhone.",
                    copy: "Orders, products, users, and trend lines stay in one quiet operational surface."
                )

                if let statusMessage {
                    Text(statusMessage)
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                }

                if isLoading {
                    ProgressView()
                        .tint(BrandPalette.accent)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                } else {
                    statsGrid
                    tabGrid
                    selectedSection
                }
            }
            .padding(viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Sales Today", value: "\(Int(stats?.todaySales ?? 0)) EGP", icon: "dollarsign.circle")
            StatCard(title: "Orders Today", value: "\(stats?.todayOrders ?? 0)", icon: "bag")
            StatCard(title: "New Users", value: "\(stats?.newUsers ?? 0)", icon: "person.badge.plus")
            StatCard(title: "Pending", value: "\(stats?.pendingOrders ?? 0)", icon: "clock")
        }
    }

    private var tabGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(AdminTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .light))
                        Text(tab.rawValue)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: selectedTab == tab ? .gold : .chrome))
            }
        }
    }

    @ViewBuilder
    private var selectedSection: some View {
        switch selectedTab {
        case .overview:
            OverviewSection(
                recentOrders: Array(store.adminOrders.prefix(5)),
                analytics: store.analytics
            )
        case .products:
            AdminProductsSection(products: store.adminProducts)
        case .orders:
            AdminOrdersSection(orders: store.adminOrders)
        case .users:
            AdminUsersSection(users: store.adminUsers)
        case .analytics:
            AdminAnalyticsSection(analytics: store.analytics)
        }
    }

    private var accessDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(BrandPalette.textMuted)

            Text("Access Denied")
                .font(BrandFont.mobileTitle())
                .foregroundStyle(BrandPalette.textPrimary)

            Text("This dashboard is only available to authenticated admin accounts.")
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        await store.fetchAdminData()

        do {
            stats = try await APIService.shared.fetchDashboardStats()
            if store.adminOrders.isEmpty {
                statusMessage = "No live admin data is available yet."
            }
        } catch {
            statusMessage = "Some live dashboard metrics are unavailable. Showing the data already loaded on this device."
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(BrandPalette.accent)

            Text(value)
                .font(BrandFont.mobileTitle3())
                .foregroundStyle(BrandPalette.textPrimary)

            Text(title)
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textSecondary)
                .tracking(0.8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: false)
    }
}

private struct OverviewSection: View {
    let recentOrders: [Order]
    let analytics: AnalyticsData?

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.xl) {
            if !recentOrders.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Orders")
                        .font(BrandFont.mobileTitle2())
                        .foregroundStyle(BrandPalette.textPrimary)

                    ForEach(recentOrders) { order in
                        NavigationLink {
                            AdminOrderDetailView(order: order)
                        } label: {
                            AdminOrderRow(order: order)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let analytics {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sales Overview")
                        .font(BrandFont.mobileTitle2())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Chart(analytics.salesByDay.prefix(7)) { day in
                        BarMark(
                            x: .value("Day", day.date),
                            y: .value("Sales", day.amount)
                        )
                        .foregroundStyle(BrandPalette.accent.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
            }
        }
    }
}

private struct AdminProductsSection: View {
    @Environment(AurelienStore.self) private var store

    let products: [Product]
    @State private var searchText = ""
    @State private var isShowingAddProduct = false
    @State private var productPendingEdit: Product?
    @State private var statusMessage: String?
    @State private var productPendingDeletion: Product?
    @State private var isDeletingProductID: String?

    private var filteredProducts: [Product] {
        guard !searchText.isEmpty else { return products }
        return products.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.category.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Products")
                        .font(BrandFont.mobileTitle2())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text("\(products.count) live items")
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)
                }

                Spacer()

                Button {
                    isShowingAddProduct = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .accessibilityLabel("Add product")
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)
            }

            adminSearchField(title: "Search products...", text: $searchText)

            ForEach(filteredProducts) { product in
                HStack(spacing: 10) {
                    NavigationLink {
                        AdminProductDetailView(product: product)
                    } label: {
                        AdminProductRow(product: product)
                    }
                    .buttonStyle(.plain)

                    Button {
                        productPendingEdit = product
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(BrandCapsuleButtonStyle(tone: .chrome))
                    .accessibilityLabel("Edit \(product.name)")
                    .disabled(isDeletingProductID != nil)

                    Button {
                        productPendingDeletion = product
                    } label: {
                        if isDeletingProductID == product.id {
                            ProgressView()
                                .tint(BrandPalette.textPrimary)
                        } else {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(BrandCapsuleButtonStyle(tone: .chrome))
                    .accessibilityLabel("Delete \(product.name)")
                    .disabled(isDeletingProductID != nil)
                }
            }
        }
        .sheet(isPresented: $isShowingAddProduct) {
            AdminAddProductView { product in
                do {
                    let created = try await store.createAdminProduct(product)
                    statusMessage = "\(created.name) was added to the catalog."
                    isShowingAddProduct = false
                } catch {
                    throw error
                }
            }
        }
        .sheet(item: $productPendingEdit) { product in
            AdminAddProductView(product: product) { updatedProduct in
                do {
                    let updated = try await store.updateAdminProduct(updatedProduct)
                    statusMessage = "\(updated.name) was updated."
                    productPendingEdit = nil
                } catch {
                    throw error
                }
            }
        }
        .alert(
            "Delete Product?",
            isPresented: Binding(
                get: { productPendingDeletion != nil },
                set: { if !$0 { productPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                productPendingDeletion = nil
            }
            Button("Delete", role: .destructive) {
                guard let product = productPendingDeletion else { return }
                deleteProduct(product)
            }
        } message: {
            Text("This removes the product from the admin catalog and product listings.")
        }
    }

    private func deleteProduct(_ product: Product) {
        isDeletingProductID = product.id
        statusMessage = nil

        Task {
            do {
                try await store.deleteAdminProduct(id: product.id)
                await MainActor.run {
                    statusMessage = "\(product.name) was deleted."
                    productPendingDeletion = nil
                    isDeletingProductID = nil
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    productPendingDeletion = nil
                    isDeletingProductID = nil
                }
            }
        }
    }
}

private struct AdminAddProductView: View {
    private let existingProduct: Product?
    let onSubmit: (Product) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: ProductCategory = .shirts
    @State private var price = ""
    @State private var summary = ""
    @State private var story = ""
    @State private var imageNames = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoPreview: UIImage?
    @State private var sizes = ""
    @State private var colors = ""
    @State private var composition = ""
    @State private var care = ""
    @State private var delivery = ""
    @State private var returnsPolicy = ""
    @State private var badge = ""
    @State private var inventory = ""
    @State private var isAvailable = true
    @State private var featured = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(product: Product? = nil, onSubmit: @escaping (Product) async throws -> Void) {
        self.existingProduct = product
        self.onSubmit = onSubmit
        _name = State(initialValue: product?.name ?? "")
        _category = State(initialValue: product?.category ?? .shirts)
        _price = State(initialValue: product.map { Self.priceText(for: $0.price) } ?? "")
        _summary = State(initialValue: product?.summary ?? "")
        _story = State(initialValue: product?.story ?? "")
        _imageNames = State(initialValue: product?.imageNames.joined(separator: ", ") ?? "")
        _sizes = State(initialValue: product?.sizes.joined(separator: ", ") ?? "")
        _colors = State(initialValue: product?.colors.map(\.name).joined(separator: ", ") ?? "")
        _composition = State(initialValue: product?.composition ?? "")
        _care = State(initialValue: product?.care ?? "")
        _delivery = State(initialValue: product?.delivery ?? "")
        _returnsPolicy = State(initialValue: product?.returns ?? "")
        _badge = State(initialValue: product?.badge?.rawValue ?? "")
        _inventory = State(initialValue: product?.inventoryCount.map(String.init) ?? "")
        _isAvailable = State(initialValue: product?.isAvailable ?? true)
        _featured = State(initialValue: product?.featured ?? false)
    }

    var body: some View {
        NavigationStack {
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
                            .clipShape(RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous))
                    }

                    TextField("Extra image names or URLs", text: $imageNames, axis: .vertical)
                        .lineLimit(2...5)

                    TextField("Sizes", text: $sizes)
                    TextField("Colors", text: $colors)
                } header: {
                    Text("Catalog Details")
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
                    Picker("Badge", selection: $badge) {
                        Text("None").tag("")
                        ForEach([ProductBadge.newArrival, .editorialPick, .bestselling], id: \.rawValue) { badge in
                            Text(badge.rawValue).tag(badge.rawValue)
                        }
                    }

                    TextField("Inventory", text: $inventory)
                        .keyboardType(.numberPad)

                    Toggle("Available", isOn: $isAvailable)
                    Toggle("Featured", isOn: $featured)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(existingProduct == nil ? "Add Product" : "Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedPhotoItem) { _, item in
                loadSelectedPhoto(item)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let uploadedImageName = try await selectedProductImageName()
                let product = try validatedProduct(selectedImageName: uploadedImageName)
                try await onSubmit(product)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    private func validatedProduct(selectedImageName: String?) throws -> Product {
        let cleanedName = name.trimmedForAdminForm
        let cleanedSummary = summary.trimmedForAdminForm
        let cleanedStory = story.trimmedForAdminForm
        var parsedImages = imageNames.adminListValues
        if let selectedImageName {
            parsedImages.insert(selectedImageName, at: 0)
        }
        let parsedSizes = sizes.adminListValues
        let parsedColors = colors.adminListValues
        let normalizedPrice = price.replacingOccurrences(of: ",", with: ".").trimmedForAdminForm
        let parsedPrice = Double(normalizedPrice) ?? .nan
        let parsedInventory = inventory.trimmedForAdminForm.isEmpty ? nil : Int(inventory.trimmedForAdminForm)

        guard cleanedName.isEmpty == false else {
            throw AdminProductFormError("Product name is required.")
        }
        guard parsedPrice.isFinite, parsedPrice > 0 else {
            throw AdminProductFormError("Enter a price greater than zero.")
        }
        guard cleanedSummary.isEmpty == false else {
            throw AdminProductFormError("Summary is required.")
        }
        guard parsedImages.isEmpty == false else {
            throw AdminProductFormError("Add at least one real image name or URL.")
        }
        guard parsedSizes.isEmpty == false else {
            throw AdminProductFormError("Add at least one size.")
        }
        guard parsedColors.isEmpty == false else {
            throw AdminProductFormError("Add at least one color.")
        }
        if inventory.trimmedForAdminForm.isEmpty == false, parsedInventory == nil {
            throw AdminProductFormError("Inventory must be a whole number.")
        }

        return Product(
            id: existingProduct?.id ?? "admin-\(UUID().uuidString.lowercased())",
            name: cleanedName,
            category: category,
            price: parsedPrice,
            summary: cleanedSummary,
            story: cleanedStory.isEmpty ? cleanedSummary : cleanedStory,
            imageNames: parsedImages,
            sizes: parsedSizes,
            colors: parsedColors.map { Colorway(name: $0.capitalized, hex: Colorway.hex(for: $0)) },
            composition: composition.trimmedForAdminForm,
            care: care.trimmedForAdminForm,
            delivery: delivery.trimmedForAdminForm,
            returns: returnsPolicy.trimmedForAdminForm,
            badge: ProductBadge(rawValue: badge),
            featured: featured,
            inventoryCount: parsedInventory,
            isAvailable: isAvailable
        )
    }

    private static func priceText(for value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }

    private func selectedProductImageName() async throws -> String? {
        guard let selectedPhotoData else { return nil }

        if APIConfig.usesEmbeddedStaticBackend {
            return try savePickedProductImage(data: selectedPhotoData)
        }

        return try await APIService.shared.uploadProductImage(
            data: selectedPhotoData,
            fileName: "admin-product-\(UUID().uuidString.lowercased()).jpg"
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
                let optimized = try Self.optimizedProductImageData(from: data)

                await MainActor.run {
                    selectedPhotoData = optimized.data
                    selectedPhotoPreview = optimized.preview
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
            throw AdminProductFormError("The selected photo could not be used.")
        }

        let directory = try Self.productImageDirectory()
        let url = directory.appendingPathComponent("admin-product-\(UUID().uuidString.lowercased()).jpg")
        guard let jpegData = image.jpegData(compressionQuality: 0.78) else {
            throw AdminProductFormError("The selected photo could not be saved.")
        }

        try jpegData.write(to: url, options: [.atomic])
        return url.path
    }

    private static func optimizedProductImageData(from data: Data) throws -> (data: Data, preview: UIImage) {
        guard let image = UIImage(data: data) else {
            throw AdminProductFormError("The selected photo could not be used.")
        }

        let maxDimension: CGFloat = 1600
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maxDimension ? maxDimension / longestSide : 1
        let outputImage: UIImage

        if scale < 1 {
            let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            outputImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            outputImage = image
        }

        guard let jpegData = outputImage.jpegData(compressionQuality: 0.78) else {
            throw AdminProductFormError("The selected photo could not be optimized.")
        }

        return (jpegData, outputImage)
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

private struct AdminProductFormError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

private extension String {
    var trimmedForAdminForm: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var adminListValues: [String] {
        components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmedForAdminForm }
            .filter { $0.isEmpty == false }
    }
}

private struct AdminProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                BrandPalette.surface

                MediaImage(name: product.heroImageName)
                    .scaledToFit()
                    .padding(6)
            }
            .frame(width: 64, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textPrimary)
                    .lineLimit(2)

                Text(product.category.title)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)

                Text(BrandFormatter.price(product.price))
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.accent)

                Text(product.stockLabel)
                    .font(BrandFont.mobileCaption2())
                    .tracking(1.4)
                    .foregroundStyle(product.isInStock ? (product.isLowStock ? .orange : BrandPalette.textSecondary) : .red)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(BrandPalette.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: false)
    }
}

private struct AdminOrdersSection: View {
    let orders: [Order]
    @State private var selectedStatus: OrderStatus?

    private var filteredOrders: [Order] {
        if let selectedStatus {
            return orders.filter { $0.status == selectedStatus }
        }
        return orders
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Menu {
                Button("All") { selectedStatus = nil }
                ForEach(OrderStatus.allCases) { status in
                    Button(status.title) { selectedStatus = status }
                }
            } label: {
                HStack {
                    Text(selectedStatus?.title ?? "All Orders")
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundStyle(BrandPalette.textMuted)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(cornerRadius: BrandRadius.soft, tone: .chrome, material: true)
            }
            .buttonStyle(.plain)

            ForEach(filteredOrders) { order in
                NavigationLink {
                    AdminOrderDetailView(order: order)
                } label: {
                    AdminOrderRow(order: order)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AdminOrderRow: View {
    let order: Order

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(order.id)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(order.customerName ?? order.shippingAddress?.name ?? "Unknown customer")
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)

                Text("\(order.items.count) items • \(order.shippingCity)")
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(order.status.title)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.accent)

                Text(BrandFormatter.price(order.total))
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: false)
    }
}

private struct AdminUsersSection: View {
    let users: [User]
    @State private var searchText = ""

    private var filteredUsers: [User] {
        guard !searchText.isEmpty else { return users }
        return users.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText) ||
            ($0.phone?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            adminSearchField(title: "Search users...", text: $searchText)

            ForEach(filteredUsers) { user in
                NavigationLink {
                    AdminUserDetailView(user: user)
                } label: {
                    AdminUserRow(user: user)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AdminAnalyticsSection: View {
    let analytics: AnalyticsData?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let analytics {
                analyticsCard(title: "Revenue Trend") {
                    Chart(analytics.salesByDay.prefix(14)) { day in
                        LineMark(
                            x: .value("Day", day.date),
                            y: .value("Revenue", day.amount)
                        )
                        .foregroundStyle(BrandPalette.accent.gradient)
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 180)
                }

                analyticsCard(title: "Top Products") {
                    Chart(analytics.topProducts.prefix(5), id: \.productId) { item in
                        BarMark(
                            x: .value("Revenue", item.revenue),
                            y: .value("Product", item.productName)
                        )
                        .foregroundStyle(BrandPalette.gold.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 220)
                }

                analyticsCard(title: "Order Status Breakdown") {
                    Chart(analytics.ordersByStatus, id: \.status) { item in
                        SectorMark(
                            angle: .value("Orders", item.count),
                            innerRadius: .ratio(0.58)
                        )
                        .foregroundStyle(by: .value("Status", item.status))
                    }
                    .frame(height: 220)
                }
            } else {
                Text("Analytics will appear once orders and live metrics are available.")
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brandPanel(cornerRadius: BrandRadius.soft, tone: .chrome, material: true)
            }
        }
    }

    private func analyticsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(BrandFont.mobileTitle2())
                .foregroundStyle(BrandPalette.textPrimary)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
    }
}

private struct AdminUserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(BrandPalette.accent.opacity(0.2))
                    .frame(width: 46, height: 46)

                Text(String(user.name.prefix(1)).uppercased())
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(user.name)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(user.email)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(BrandPalette.textSecondary)

                if let phone = user.phone, !phone.isEmpty {
                    Text(phone)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)
                }
            }

            Spacer()

            Text(user.isAdmin ? "ADMIN" : "USER")
                .font(BrandFont.mobileCaption2())
                .tracking(2)
                .foregroundStyle(user.isAdmin ? BrandPalette.accent : BrandPalette.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: false)
    }
}

private func adminSearchField(title: String, text: Binding<String>) -> some View {
    HStack(spacing: 12) {
        Image(systemName: "magnifyingglass")
            .foregroundStyle(BrandPalette.textSecondary)

        TextField(title, text: text)
            .font(BrandFont.mobileBody())
            .foregroundStyle(BrandPalette.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .brandPanel(cornerRadius: BrandRadius.soft, tone: .chrome, material: true)
}

struct AdminProductDetailView: View {
    @Environment(AurelienStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let product: Product
    @State private var currentProduct: Product
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var isShowingEditProduct = false
    @State private var deleteErrorMessage: String?
    @State private var statusMessage: String?

    init(product: Product) {
        self.product = product
        _currentProduct = State(initialValue: product)
    }

    var body: some View {
        PhoneScrollScreen { viewport in
            VStack(alignment: .leading, spacing: BrandSpacing.xl) {
                ZStack {
                    BrandPalette.surface

                    MediaImage(name: currentProduct.heroImageName)
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(14)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(viewport.editorialAspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous))

                detailCard(title: "Product") {
                    detailLine("ID", currentProduct.id)
                    detailLine("Name", currentProduct.name)
                    detailLine("Category", currentProduct.category.title)
                    detailLine("Price", BrandFormatter.price(currentProduct.price))
                    detailLine("Stock", currentProduct.stockLabel)
                    detailLine("Featured", currentProduct.featured ? "Yes" : "No")
                    detailLine("Available", currentProduct.isAvailable == false ? "No" : "Yes")
                    detailLine("Inventory", currentProduct.inventoryCount.map(String.init) ?? "Not provided")
                    detailLine("Badge", currentProduct.badge?.rawValue ?? "None")
                    detailLine("Rating", currentProduct.rating.map { String(format: "%.1f", $0) } ?? "Not provided")
                    detailLine("Reviews", currentProduct.reviewCount.map(String.init) ?? "Not provided")
                }

                detailCard(title: "Details") {
                    detailLine("Summary", currentProduct.summary)
                    detailLine("Story", currentProduct.story)
                    detailLine("Sizes", currentProduct.sizes.isEmpty ? "Not provided" : currentProduct.sizes.joined(separator: ", "))
                    detailLine("Colors", currentProduct.colors.isEmpty ? "Not provided" : currentProduct.colors.map(\.name).joined(separator: ", "))
                    detailLine("Composition", currentProduct.composition)
                    detailLine("Care", currentProduct.care)
                    detailLine("Delivery", currentProduct.delivery)
                    detailLine("Returns", currentProduct.returns)
                }

                detailCard(title: "Images") {
                    ForEach(Array(currentProduct.imageNames.enumerated()), id: \.offset) { index, imageName in
                        detailLine("Image \(index + 1)", imageName)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                }

                if let deleteErrorMessage {
                    Text(deleteErrorMessage)
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, viewport.bottomPadding)
        }
        .navigationTitle("Product")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isShowingEditProduct = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit product")

                Button {
                    isConfirmingDelete = true
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Image(systemName: "trash")
                    }
                }
                .disabled(isDeleting)
                .accessibilityLabel("Delete product")
            }
        }
        .sheet(isPresented: $isShowingEditProduct) {
            AdminAddProductView(product: currentProduct) { updatedProduct in
                let updated = try await store.updateAdminProduct(updatedProduct)
                currentProduct = updated
                statusMessage = "\(updated.name) was updated."
                isShowingEditProduct = false
            }
        }
        .alert("Delete Product?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteProduct()
            }
        } message: {
            Text("This removes the product from the admin catalog and product listings.")
        }
    }

    private func deleteProduct() {
        isDeleting = true
        deleteErrorMessage = nil

        Task {
            do {
                try await store.deleteAdminProduct(id: currentProduct.id)
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    deleteErrorMessage = error.localizedDescription
                    isDeleting = false
                }
            }
        }
    }
}

struct AdminOrderDetailView: View {
    let order: Order
    @Environment(AurelienStore.self) private var store
    @State private var currentOrder: Order
    @State private var isUpdatingStatus = false
    @State private var statusMessage: String?

    init(order: Order) {
        self.order = order
        _currentOrder = State(initialValue: order)
    }

    var body: some View {
        PhoneScrollScreen { viewport in
            VStack(alignment: .leading, spacing: BrandSpacing.xl) {
                detailCard(title: "Tracking") {
                    OrderTrackingTimeline(status: currentOrder.status)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Update Status".uppercased())
                            .font(BrandFont.mobileCaption2())
                            .tracking(3)
                            .foregroundStyle(BrandPalette.textMuted)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(OrderStatus.allCases) { status in
                                Button {
                                    updateStatus(status)
                                } label: {
                                    HStack(spacing: 8) {
                                        if isUpdatingStatus && currentOrder.status != status {
                                            ProgressView()
                                                .tint(BrandPalette.textPrimary)
                                        } else {
                                            Image(systemName: currentOrder.status == status ? "checkmark.circle.fill" : "circle")
                                        }
                                        Text(status.title)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.78)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(BrandCapsuleButtonStyle(tone: currentOrder.status == status ? .gold : .chrome))
                                .disabled(isUpdatingStatus || currentOrder.status == status)
                            }
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.textSecondary)
                    }
                }

                detailCard(title: "Order") {
                    detailLine("ID", currentOrder.id)
                    detailLine("Status", currentOrder.status.title)
                    if let createdAt = currentOrder.createdAt {
                        detailLine("Created", createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    detailLine("Subtotal", BrandFormatter.price(currentOrder.subtotal))
                    detailLine("Shipping", BrandFormatter.price(currentOrder.shippingCost))
                    detailLine("Discount", currentOrder.discount != 0 ? BrandFormatter.discount(currentOrder.discount) : "-")
                    detailLine("Total", BrandFormatter.price(currentOrder.total))
                    detailLine("Shipping Method", currentOrder.shippingMethodName ?? "Not provided")
                }

                detailCard(title: "Customer") {
                    detailLine("Name", currentOrder.customerName ?? currentOrder.shippingAddress?.name ?? "Not provided")
                    detailLine("Email", currentOrder.customerEmail ?? currentOrder.shippingAddress?.email ?? "Not provided")
                    detailLine("Phone", currentOrder.customerPhone ?? currentOrder.shippingAddress?.phone ?? "Not provided")
                }

                detailCard(title: "Shipping") {
                    detailLine("City", currentOrder.shippingAddress?.city ?? currentOrder.shippingCity)
                    detailLine("Street", currentOrder.shippingAddress?.street ?? "Not provided")
                    detailLine("Apartment", currentOrder.shippingAddress?.apartment ?? "Not provided")
                    detailLine("Postal Code", currentOrder.shippingAddress?.postalCode ?? "Not provided")
                }

                detailCard(title: "Items") {
                    ForEach(currentOrder.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            detailLine("Name", item.name)
                            detailLine("Quantity", "\(item.quantity)")
                            detailLine("Size", item.size ?? "One Size")
                            detailLine("Color", item.color ?? "Default")
                            detailLine("Unit Price", BrandFormatter.price(item.price))
                        }
                        .padding(.bottom, 10)
                    }
                }
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, viewport.bottomPadding)
        }
        .navigationTitle("Order")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Orders")
    }

    private func updateStatus(_ status: OrderStatus) {
        isUpdatingStatus = true
        statusMessage = nil

        Task {
            do {
                let updated = try await store.updateAdminOrderStatus(id: currentOrder.id, status: status)
                await MainActor.run {
                    currentOrder = updated
                    statusMessage = "Order moved to \(updated.status.title)."
                    isUpdatingStatus = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
                    isUpdatingStatus = false
                }
            }
        }
    }
}

struct AdminUserDetailView: View {
    let user: User

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: BrandSpacing.xl) {
                detailCard(title: "User") {
                    detailLine("ID", user.id)
                    detailLine("Name", user.name)
                    detailLine("Email", user.email)
                    detailLine("Phone", user.phone ?? "Not provided")
                    detailLine("Role", user.isAdmin ? "Administrator" : "Client")
                    if let createdAt = user.createdAt {
                        detailLine("Created", createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let updatedAt = user.updatedAt {
                        detailLine("Updated", updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 120)
        }
        .navigationTitle("User")
        .navigationBarTitleDisplayMode(.inline)
        .boutBackButton("Users")
    }
}

private func detailCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(BrandFont.mobileTitle2())
            .foregroundStyle(BrandPalette.textPrimary)

        content()
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: false)
}

private func detailLine(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label.uppercased())
            .font(BrandFont.mobileCaption2())
            .tracking(3)
            .foregroundStyle(BrandPalette.textMuted)

        Text(value)
            .font(BrandFont.mobileBody())
            .foregroundStyle(BrandPalette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
