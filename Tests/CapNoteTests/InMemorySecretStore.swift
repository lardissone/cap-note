import Foundation
@testable import CapNote

final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]
    private var savesFail = false

    init(_ items: [String: Data] = [:]) {
        self.items = items
    }

    func read(account: String) throws -> Data? {
        lock.withLock { items[account] }
    }

    func save(_ data: Data, account: String) throws {
        try lock.withLock {
            if savesFail { throw Keychain.KeychainError.unexpectedStatus(errSecInteractionNotAllowed) }
            items[account] = data
        }
    }

    /// Makes every later `save` fail, as a Keychain that denies writes would.
    func failSaves() {
        lock.withLock { savesFail = true }
    }

    func delete(account: String) throws {
        lock.withLock { items[account] = nil }
    }

    func accounts() throws -> [String] {
        lock.withLock { Array(items.keys) }
    }
}
