import SwiftUI

struct ClosetView: View {
    @State private var items: [ClosetItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    SkeletonView()
                } else if let errorMessage = errorMessage {
                    ErrorStateView(message: errorMessage, retry: loadCloset)
                } else if items.isEmpty {
                    EmptyStateView(icon: "tshirt", message: "Your closet is empty.", actionTitle: "Add Item", action: { showAddSheet = true })
                } else {
                    List {
                        ForEach(items) { item in
                            ClosetItemRow(item: item)
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("My Closet")
            .toolbar {
                Button(action: { showAddSheet = true }) {
                    Label("Add Item", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddClosetItemView(onAdd: { newItem in
                    items.append(newItem)
                    showAddSheet = false
                })
            }
            .onAppear(perform: loadCloset)
        }
    }
    
    func loadCloset() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetched: [ClosetItem] = try await APIService.shared.request("/closet")
                await MainActor.run {
                    self.items = fetched
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    // ROOT CAUSE: Use AppErrorHandler to categorize error
                    let (_, message, suggestion) = AppErrorHandler.categorize(error)
                    self.errorMessage = [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
                    self.isLoading = false
                }
            }
        }
    }
    func deleteItems(at offsets: IndexSet) {
        let idsToDelete = offsets.map { items[$0].id }
        items.remove(atOffsets: offsets)
        Task {
            for id in idsToDelete {
                let _: EmptyResponse? = try? await APIService.shared.request("/closet/\(id)", method: "DELETE")
            }
        }
    }
}

struct ClosetItem: Identifiable, Codable {
    let id: String
    var name: String
    var color: Color
    var brand: String
    var image: Image?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case colorDescription = "color"
    }

    init(id: String = UUID().uuidString, name: String, color: Color, brand: String, image: Image? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.brand = brand
        self.image = image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decode(String.self, forKey: .brand)
        _ = try container.decodeIfPresent(String.self, forKey: .colorDescription)
        color = .gray
        image = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(brand, forKey: .brand)
        try container.encode(String(describing: color), forKey: .colorDescription)
    }
}

struct ClosetItemRow: View {
    let item: ClosetItem
    var body: some View {
        HStack {
            if let image = item.image {
                image.resizable().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8).fill(item.color).frame(width: 48, height: 48)
            }
            VStack(alignment: .leading) {
                Text(item.name).font(.headline)
                Text(item.brand).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

struct AddClosetItemView: View {
    var onAdd: (ClosetItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color = Color.gray
    @State private var brand = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                ColorPicker("Color", selection: $color)
                TextField("Brand", text: $brand)
                if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addItem()
                    }.disabled(isLoading)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    func addItem() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                struct ClosetItemRequest: Codable { let name: String; let color: String; let brand: String }
                let req = ClosetItemRequest(name: name, color: color.description, brand: brand)
                let data = try JSONEncoder().encode(req)
                let created: ClosetItem = try await APIService.shared.request("/closet", method: "POST", body: data)
                await MainActor.run {
                    onAdd(created)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
