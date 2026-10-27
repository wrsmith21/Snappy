import Foundation
import Observation
import SnappyCore

/// The user's saved snaps, newest first.
@MainActor
@Observable
final class SnapLibrary {
    static let shared = SnapLibrary()

    private(set) var snaps: [Snap]

    @ObservationIgnored private let archive: SnapArchive

    init(archive: SnapArchive = SnapArchive(fileURL: SnapLibrary.defaultFileURL)) {
        self.archive = archive
        do {
            snaps = try archive.load()
        } catch {
            print("Couldn't load snaps: \(error)")
            snaps = []
        }
    }

    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "snaps.json")
    }

    func add(_ snap: Snap) {
        snaps.insert(snap, at: 0)
        persist()
    }

    func delete(at offsets: IndexSet) {
        snaps.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        do {
            try archive.save(snaps)
        } catch {
            print("Couldn't save snaps: \(error)")
        }
    }
}
