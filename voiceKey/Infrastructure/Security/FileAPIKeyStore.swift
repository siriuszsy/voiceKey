import Foundation

final class FileAPIKeyStore: APIKeyStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try trimmed.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func load() throws -> String {
        try String(contentsOf: fileURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func hasStoredKey() -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return false
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return false
        }

        return !data.isEmpty
    }
}
