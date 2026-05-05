import Foundation

/// Robust network client with retry, cancellation, deduplication, and offline cache
final class NetworkClient {
    static let shared = NetworkClient()
    private let urlSession: URLSession
    private let cache = URLCache(memoryCapacity: 20_000_000, diskCapacity: 100_000_000)
    private let inFlightTasks = InFlightTaskRegistry()

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .useProtocolCachePolicy
        urlSession = URLSession(configuration: config)
    }

    @discardableResult
    func fetch(_ url: URL, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy, timeout: TimeInterval = 15) async throws -> Data {
        let task = await inFlightTasks.task(for: url) { [urlSession, inFlightTasks] in
            Task<Data, Error> {
                let request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)

                do {
                    var attempt = 0
                    let maxAttempts = 3
                    let baseDelay: Double = 0.5
                    while true {
                        do {
                            let (data, response) = try await urlSession.data(for: request)
                            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                                await inFlightTasks.removeTask(for: url)
                                return data
                            } else {
                                throw URLError(.badServerResponse)
                            }
                        } catch {
                            attempt += 1
                            if attempt >= maxAttempts { throw error }
                            let jitter = Double.random(in: 0..<0.3)
                            try await Task.sleep(nanoseconds: UInt64((baseDelay * pow(2, Double(attempt - 1)) + jitter) * 1_000_000_000))
                        }
                    }
                } catch {
                    await inFlightTasks.removeTask(for: url)
                    throw error
                }
            }
        }
        return try await task.value
    }
}

private actor InFlightTaskRegistry {
    private var tasks: [URL: Task<Data, Error>] = [:]

    func task(for url: URL, create: @escaping @Sendable () -> Task<Data, Error>) -> Task<Data, Error> {
        if let existing = tasks[url] {
            return existing
        }

        let task = create()
        tasks[url] = task
        return task
    }

    func removeTask(for url: URL) {
        tasks[url] = nil
    }
}
