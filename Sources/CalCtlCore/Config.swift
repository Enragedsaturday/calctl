import Foundation

public struct CalCtlConfig: Codable, Equatable {
    public var version: Int
    public var aliases: [String: String]

    public init(version: Int = 1, aliases: [String: String] = [:]) {
        self.version = version
        self.aliases = aliases
    }
}

public struct ConfigStore {
    public let fileURL: URL

    public init(fileURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".calctl/config.json")) {
        self.fileURL = fileURL
    }

    public func load() throws -> CalCtlConfig {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return CalCtlConfig() }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(CalCtlConfig.self, from: data)
    }

    public func save(_ config: CalCtlConfig) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    public func resolve(_ aliasOrID: String) throws -> String {
        let config = try load()
        return config.aliases[aliasOrID] ?? aliasOrID
    }

    public func setAlias(name: String, id: String) throws -> CalCtlConfig {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.range(of: #"^[A-Za-z0-9_.-]{1,64}$"#, options: .regularExpression) != nil else {
            throw CalCtlError.validation("Alias must be 1-64 chars: letters, numbers, underscore, dash, dot")
        }
        var config = try load()
        config.aliases[clean] = id
        try save(config)
        return config
    }

    public func removeAlias(name: String) throws -> Bool {
        var config = try load()
        guard config.aliases.removeValue(forKey: name) != nil else { return false }
        try save(config)
        return true
    }
}
