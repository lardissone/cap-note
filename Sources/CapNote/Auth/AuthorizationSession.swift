import AppKit
import AuthenticationServices

/// Presents the Capacities sign-in page and returns the redirect URL it ends on.
@MainActor
final class AuthorizationSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthorizationSession()

    /// Kept alive for the duration of the flow; the system doesn't retain it.
    private var current: ASWebAuthenticationSession?

    func authorize(url: URL, callbackScheme: String) async throws -> URL {
        defer { current = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let outcome = Outcome(continuation)
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callback, error in
                if let callback {
                    outcome.finish(.success(callback))
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    outcome.finish(.failure(ConnectionError.cancelled))
                } else {
                    outcome.finish(.failure(error ?? ConnectionError.invalidCallback))
                }
            }
            session.presentationContextProvider = self
            current = session
            if !session.start() {
                outcome.finish(.failure(ConnectionError.couldNotStart))
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
        }
    }

    /// Resumes the continuation once, whichever of `start()` failing or the completion
    /// handler reports first.
    private final class Outcome: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<URL, Error>?

        init(_ continuation: CheckedContinuation<URL, Error>) {
            self.continuation = continuation
        }

        func finish(_ result: Result<URL, Error>) {
            let pending = lock.withLock { () -> CheckedContinuation<URL, Error>? in
                defer { continuation = nil }
                return continuation
            }
            pending?.resume(with: result)
        }
    }
}
