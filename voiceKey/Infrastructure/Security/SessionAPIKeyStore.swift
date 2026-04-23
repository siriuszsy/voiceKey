import Foundation

final class SessionAPIKeyStore: APIKeyStore, @unchecked Sendable {
    private let lock = NSLock()
    private var key: String?

    func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        lock.lock()
        self.key = trimmed
        lock.unlock()
    }

    func load() throws -> String {
        lock.lock()
        let storedKey = key
        lock.unlock()

        guard let storedKey else {
            throw NSError(domain: "SessionAPIKeyStore", code: 1)
        }

        return storedKey
    }

    func hasStoredKey() -> Bool {
        lock.lock()
        let storedKey = key
        lock.unlock()
        guard let storedKey else {
            return false
        }
        return !storedKey.isEmpty
    }
}
