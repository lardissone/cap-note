import Foundation

extension HTTPURLResponse {
    static func ok(_ request: URLRequest) -> HTTPURLResponse {
        status(200, request)
    }

    static func status(_ code: Int, _ request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
}

extension URLRequest {
    /// URLProtocol receives the body as a stream rather than `httpBody`.
    var bodyData: Data? {
        guard let stream = httpBodyStream else { return httpBody }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    /// Decodes an `application/x-www-form-urlencoded` body.
    var formFields: [String: String] {
        let body = String(decoding: bodyData ?? Data(), as: UTF8.self)
        var fields: [String: String] = [:]
        for pair in body.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            let key = parts[0].removingPercentEncoding ?? parts[0]
            let value = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : ""
            fields[key] = value
        }
        return fields
    }
}
