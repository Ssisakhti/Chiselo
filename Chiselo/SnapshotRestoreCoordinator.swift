import Foundation

typealias SnapshotRestoreCommitHandler = (
    _ temporaryURL: URL,
    _ destinationURL: URL,
    _ destinationExists: Bool
) throws -> Void

enum SnapshotRestoreError: LocalizedError {
    case sourceMatchesDestination
    case transactionFailed(String, rollbackFailure: String?)

    var errorDescription: String? {
        switch self {
        case .sourceMatchesDestination:
            return "The snapshot and current file use the same path"
        case .transactionFailed(let message, let rollbackFailure):
            if let rollbackFailure {
                return "Restore failed: \(message). Automatic rollback also failed: \(rollbackFailure)"
            }
            return "Restore failed. The original file was kept automatically: \(message)"
        }
    }
}

func restoreSnapshotFile(
    from snapshotURL: URL,
    to destinationURL: URL,
    fileManager: FileManager = .default,
    commitHandler: SnapshotRestoreCommitHandler? = nil
) throws {
    let source = snapshotURL.standardizedFileURL.resolvingSymlinksInPath()
    let destination = destinationURL.standardizedFileURL.resolvingSymlinksInPath()
    guard source.path != destination.path else {
        throw SnapshotRestoreError.sourceMatchesDestination
    }

    let restoredData = try Data(contentsOf: source)
    let destinationExists = fileManager.fileExists(atPath: destination.path)
    let originalData = destinationExists ? try Data(contentsOf: destination) : nil
    let temporaryURL = destination.deletingLastPathComponent()
        .appendingPathComponent(".chiselo-restore-\(UUID().uuidString)")
    try restoredData.write(to: temporaryURL, options: [.atomic])
    defer {
        if fileManager.fileExists(atPath: temporaryURL.path) {
            try? fileManager.removeItem(at: temporaryURL)
        }
    }

    do {
        if let commitHandler {
            try commitHandler(temporaryURL, destination, destinationExists)
        } else if destinationExists {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: destination)
        }
    } catch {
        let rollbackFailure: Error?
        do {
            if let originalData {
                try originalData.write(to: destination, options: [.atomic])
            } else if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            rollbackFailure = nil
        } catch let rollbackError {
            rollbackFailure = rollbackError
        }
        throw SnapshotRestoreError.transactionFailed(
            error.localizedDescription,
            rollbackFailure: rollbackFailure?.localizedDescription
        )
    }
}
