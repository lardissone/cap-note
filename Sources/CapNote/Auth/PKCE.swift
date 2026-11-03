import CryptoKit
import Foundation
import Security

/// Proof Key for Code Exchange (RFC 7636), S256 method.
enum PKCE {
    /// 32 random bytes, base64url-encoded: 43 characters, the minimum the spec allows.
    static func makeVerifier() -> String {
        randomURLSafeString(byteCount: 32)
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    /// Opaque value echoed back by the authorization server to tie the callback to this request.
    static func makeState() -> String {
        randomURLSafeString(byteCount: 16)
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed with status \(status)")
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
