import Foundation

public struct SnapshotStore: Sendable {
    public enum StoreError: Error, LocalizedError, Sendable {
        case appGroupUnavailable(String)

        public var errorDescription: String? {
            switch self {
            case let .appGroupUnavailable(identifier):
                "无法访问 App Group：\(identifier)"
            }
        }
    }

    public let directoryURL: URL
    public let snapshotURL: URL

    public init(directoryURL: URL, fileName: String = "quota-snapshot.json") {
        self.directoryURL = directoryURL
        snapshotURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    public static func shared(
        fileManager: FileManager = .default
    ) throws -> SnapshotStore {
        guard let directory = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: QuotaConstants.appGroupIdentifier
        ) else {
            throw StoreError.appGroupUnavailable(QuotaConstants.appGroupIdentifier)
        }
        return SnapshotStore(directoryURL: directory)
    }

    public func load(fileManager: FileManager = .default) throws -> QuotaSnapshot? {
        guard fileManager.fileExists(atPath: snapshotURL.path) else { return nil }
        let data = try Data(contentsOf: snapshotURL)
        return try Self.decoder.decode(QuotaSnapshot.self, from: data)
    }

    public func save(
        _ snapshot: QuotaSnapshot,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: [.atomic])
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
