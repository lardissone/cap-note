import XCTest
@testable import CapNote

final class CredentialsMigrationTests: XCTestCase {
    func test_legacyToken_isRemoved() throws {
        let secrets = InMemorySecretStore([CredentialsMigration.legacyAccount: Data("old-token".utf8)])

        XCTAssertTrue(try CredentialsMigration.removeLegacyToken(from: secrets))
        XCTAssertNil(try secrets.read(account: CredentialsMigration.legacyAccount))
    }

    func test_noLegacyToken_needsNothing() throws {
        XCTAssertFalse(try CredentialsMigration.removeLegacyToken(from: InMemorySecretStore()))
    }
}
