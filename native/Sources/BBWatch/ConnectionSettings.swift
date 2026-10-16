import Foundation
import Security

struct ConnectionSettings: Codable, Equatable {
    var serverURL: String = ""
    var token: String = ""
    var machineID: String = ""
    var identity: String { serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "|" + machineID }

    static func load() throws -> Self {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "dev.tokenville.bbwatch.connection",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary, &result)
        if status == errSecItemNotFound { return Self() }
        guard status == errSecSuccess, let data = result as? Data else { throw ConnectionError.keychain }
        return try JSONDecoder().decode(Self.self, from: data)
    }
    func save() throws {
        guard let url = URL(string: serverURL), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw ConnectionError.invalidURL
        }
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: "dev.tokenville.bbwatch.connection"] as CFDictionary
        let data = try JSONEncoder().encode(self)
        let status = SecItemUpdate(query, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd([
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: "dev.tokenville.bbwatch.connection",
                kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ] as CFDictionary, nil)
            guard added == errSecSuccess else { throw ConnectionError.keychain }
        } else if status != errSecSuccess { throw ConnectionError.keychain }
    }
}
enum ConnectionError: LocalizedError {
    case keychain, invalidURL, notConnected
    var errorDescription: String? {
        switch self {
        case .keychain: return "Could not access secure connection settings."
        case .invalidURL: return "Enter a secure BB address without a password, query, or fragment."
        case .notConnected: return "Connect BB to send. The recording is saved on this watch."
        }
    }
}
