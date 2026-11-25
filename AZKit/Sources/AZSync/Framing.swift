import AZModel
import Foundation

/// Frames on the wire: a 4-byte big-endian length, then that many bytes of JSON.
public enum Framing {
    /// Big enough for a meal photo. Anything larger is a bug or an attack, and closes the connection.
    public static let maxFrame = 16 * 1024 * 1024

    public enum Failure: Error, Equatable {
        case tooLarge(Int)
    }

    public static func frame(_ message: Message) throws -> Data {
        let body = try DivJSON.encode(message, pretty: false)
        var length = UInt32(body.count).bigEndian
        return Data(bytes: &length, count: 4) + body
    }
}

/// Collects bytes as they arrive and hands back whole frames.
public struct FrameBuffer: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func append(_ data: Data) {
        buffer.append(data)
    }

    /// The next complete frame's body, or nil until more bytes arrive.
    public mutating func next() throws(Framing.Failure) -> Data? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.prefix(4).reduce(0) { $0 << 8 | Int($1) }
        guard length <= Framing.maxFrame else { throw .tooLarge(length) }
        guard buffer.count >= 4 + length else { return nil }
        let start = buffer.startIndex + 4
        let body = Data(buffer[start..<start + length])
        buffer = Data(buffer[(start + length)...])
        return body
    }
}
