import Foundation

public struct Output {
    public static func success(_ value: Any) -> String { encode(normalize(value)) }
    public static func error(_ message: String) -> String { encode(["status": "error", "error": message]) }

    public static func successData(_ value: Any) throws -> Data {
        try encodeData(normalize(value))
    }

    public static func errorData(_ message: String) throws -> Data {
        try encodeData(["status": "error", "error": message])
    }

    private static func normalize(_ value: Any) -> Any {
        if var dict = value as? [String: Any] {
            if dict["status"] == nil { dict["status"] = "success" }
            return dict
        }
        return ["status": "success", "result": value]
    }

    private static func encodeData(_ value: Any) throws -> Data {
        guard JSONSerialization.isValidJSONObject(value) else {
            throw CalCtlError.validation("JSON serialization failed")
        }
        return try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    }

    private static func encode(_ value: Any) -> String {
        guard let data = try? encodeData(value),
              let text = String(data: data, encoding: .utf8) else {
            let fallback = ["status": "error", "error": "JSON serialization failed"]
            let data = try! JSONSerialization.data(withJSONObject: fallback, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8)!
        }
        return text
    }
}
