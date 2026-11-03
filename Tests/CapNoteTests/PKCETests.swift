import XCTest
@testable import CapNote

final class PKCETests: XCTestCase {
    func test_challenge_matchesRFC7636Example() {
        XCTAssertEqual(
            PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        )
    }

    func test_verifier_isURLSafeAndWithinAllowedLength() {
        let verifier = PKCE.makeVerifier()
        XCTAssertTrue((43...128).contains(verifier.count))
        XCTAssertNil(verifier.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
    }

    func test_verifiers_areRandom() {
        XCTAssertNotEqual(PKCE.makeVerifier(), PKCE.makeVerifier())
    }
}
