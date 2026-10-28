import Foundation

/// Reads and writes the list of snaps as a JSON file.
public struct SnapArchive: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The saved snaps, or none if nothing has been saved yet.
    public func load() throws -> [Snap] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode(Contents.self, from: data).snaps
    }

    public func save(_ snaps: [Snap]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(Contents(version: Contents.currentVersion, snaps: snaps))
        try data.write(to: fileURL, options: .atomic)
    }

    private struct Contents: Codable {
        static let currentVersion = 1

        var version: Int
        var snaps: [Snap]
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
