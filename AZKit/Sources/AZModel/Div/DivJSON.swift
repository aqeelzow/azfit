import Foundation

/// The JSON coders for everything Div reads and returns. Keys are snake_case on the wire and camelCase in Swift.
///
/// Avoid digits right after an underscore in key names (`last_7`): they don't survive the round trip.
public enum DivJSON {
    /// camelCase to snake_case, splitting only before capitals: `bestE1rm` is `best_e1rm`. Foundation's own
    /// `.convertToSnakeCase` also splits before digits (`best_e_1rm`), which wouldn't read back.
    public static func snakeCase(_ key: String) -> String {
        var out = ""
        for character in key {
            if character.isUppercase {
                if !out.isEmpty { out.append("_") }
                out.append(contentsOf: character.lowercased())
            } else {
                out.append(character)
            }
        }
        return out
    }

    /// snake_case to camelCase: `best_e1rm` is `bestE1rm`. The exact reverse of `snakeCase`.
    public static func camelCase(_ key: String) -> String {
        let parts = key.split(separator: "_", omittingEmptySubsequences: false)
        guard let first = parts.first else { return key }
        return String(first) + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int?
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    public static func encoder(pretty: Bool = true) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .custom { path in Key(stringValue: snakeCase(path.last?.stringValue ?? "")) }
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom { path in Key(stringValue: camelCase(path.last?.stringValue ?? "")) }
        return decoder
    }

    public static func encode<T: Encodable>(_ value: T, pretty: Bool = true) throws -> Data {
        try encoder(pretty: pretty).encode(value)
    }

    public static func string<T: Encodable>(_ value: T, pretty: Bool = true) throws -> String {
        String(decoding: try encode(value, pretty: pretty), as: UTF8.self)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder().decode(type, from: data)
    }
}
