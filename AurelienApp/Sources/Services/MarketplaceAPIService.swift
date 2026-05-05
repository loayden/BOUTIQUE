import Foundation

final class MarketplaceAPIService {
    static let shared = MarketplaceAPIService()
    private let session = URLSession.shared
    private var ongoingTasks: [String: URLSessionDataTask] = [:]
    private let cache = URLCache.shared

    private init() {}

    private var baseURL: URL {
        let rawBase = APIConfig.apiBaseURL.hasSuffix("/") ? APIConfig.apiBaseURL : "\(APIConfig.apiBaseURL)/"
        return URL(string: rawBase) ?? URL(fileURLWithPath: "/")
    }

    private func endpointURL(_ endpoint: String) -> URL {
        let normalized = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        return URL(string: normalized, relativeTo: baseURL)?.absoluteURL ?? baseURL.appendingPathComponent(normalized)
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[MarketplaceAPIService] \(message)")
        #endif
    }

    func cancelRequest(for endpoint: String) {
        ongoingTasks[endpoint]?.cancel()
        ongoingTasks.removeValue(forKey: endpoint)
    }

    // MARK: - Map View
    func fetchBoutiquesWithLocation(completion: @escaping (Result<[MarketplaceBoutique], Error>) -> Void) {
        let url = endpointURL("/boutiques?nearby=true")
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            do {
                let boutiques = try JSONDecoder().decode([MarketplaceBoutique].self, from: data)
                completion(.success(boutiques))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Outfit Builder
    func fetchOutfits(completion: @escaping (Result<[Outfit], Error>) -> Void) {
        let url = endpointURL("/outfits")
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            do {
                let outfits = try JSONDecoder().decode([Outfit].self, from: data)
                completion(.success(outfits))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    func saveOutfit(_ outfit: Outfit, completion: @escaping (Result<Void, Error>) -> Void) {
        var request = URLRequest(url: endpointURL("/outfits"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(outfit)
        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }
        task.resume()
    }

    // MARK: - Style Feed
    func fetchFeed(completion: @escaping (Result<[FeedPost], Error>) -> Void) {
        let url = endpointURL("/feed")
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            do {
                let posts = try JSONDecoder().decode([FeedPost].self, from: data)
                completion(.success(posts))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Boutique Stories
    func fetchStories(forBoutiqueId id: String, completion: @escaping (Result<[Story], Error>) -> Void) {
        let url = endpointURL("/boutiques/\(id)/stories")
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            do {
                let stories = try JSONDecoder().decode([Story].self, from: data)
                completion(.success(stories))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Wishlist & Style Boards
    func fetchWishlist(completion: @escaping (Result<[Product], Error>) -> Void) {
        let url = endpointURL("/wishlist")
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            do {
                let products = try JSONDecoder().decode([Product].self, from: data)
                completion(.success(products))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Personal Stylist Chat
    func startChat(withStylist stylistId: String, completion: @escaping (Result<ChatSession, Error>) -> Void) {
        let url = endpointURL("/chat/start?stylistId=\(stylistId)")
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            do {
                let session = try JSONDecoder().decode(ChatSession.self, from: data)
                completion(.success(session))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Event Calendar
    func fetchEvents(completion: @escaping (Result<[Event], Error>) -> Void) {
        let url = endpointURL("/events")
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            do {
                let events = try JSONDecoder().decode([Event].self, from: data)
                completion(.success(events))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Try-On Scheduler
    func fetchAppointments(completion: @escaping (Result<[Appointment], Error>) -> Void) {
        let url = endpointURL("/appointments")
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            do {
                let appointments = try JSONDecoder().decode([Appointment].self, from: data)
                completion(.success(appointments))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Boutique Profiles
    func fetchBoutiqueProfile(id: String, completion: @escaping (Result<MarketplaceBoutique, Error>) -> Void) {
        let url = endpointURL("/boutiques/\(id)")
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            do {
                let boutique = try JSONDecoder().decode(MarketplaceBoutique.self, from: data)
                completion(.success(boutique))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - User Reviews & Ratings
    func fetchReviews(forBoutiqueId id: String, completion: @escaping (Result<[Review], Error>) -> Void) {
        let url = endpointURL("/reviews/\(id)")
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            do {
                let reviews = try JSONDecoder().decode([Review].self, from: data)
                completion(.success(reviews))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    func fetchProducts(completion: @escaping (Result<[MarketplaceProduct], Error>) -> Void) {
        let endpoint = "/products"
        let url = endpointURL(endpoint)
        let request = URLRequest(url: url)

        // Check cache first
        if let cached = cache.cachedResponse(for: request)?.data {
            debugLog("Using cached products response")
            if let products = try? JSONDecoder().decode([MarketplaceProduct].self, from: cached) {
                completion(.success(products))
            }
        }

        // Deduplicate
        cancelRequest(for: endpoint)
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            do {
                let products = try JSONDecoder().decode([MarketplaceProduct].self, from: data)
                // Cache response
                if let response = response {
                    let cached = CachedURLResponse(response: response, data: data)
                    self?.cache.storeCachedResponse(cached, for: request)
                }
                completion(.success(products))
            } catch {
                completion(.failure(error))
            }
        }
        ongoingTasks[endpoint] = task
        task.resume()
    }

    func fetchNearbyBoutiques(completion: @escaping (Result<[MarketplaceBoutique], Error>) -> Void) {
        let endpoint = "/boutiques/nearby"
        let url = endpointURL(endpoint)
        let request = URLRequest(url: url)

        // Check cache first
        if let cached = cache.cachedResponse(for: request)?.data {
            debugLog("Using cached boutiques response")
            if let boutiques = try? JSONDecoder().decode([MarketplaceBoutique].self, from: cached) {
                completion(.success(boutiques))
            }
        }

        // Deduplicate
        cancelRequest(for: endpoint)
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            do {
                let boutiques = try JSONDecoder().decode([MarketplaceBoutique].self, from: data)
                // Cache response
                if let response = response {
                    let cached = CachedURLResponse(response: response, data: data)
                    self?.cache.storeCachedResponse(cached, for: request)
                }
                completion(.success(boutiques))
            } catch {
                completion(.failure(error))
            }
        }
        ongoingTasks[endpoint] = task
        task.resume()
    }
}
