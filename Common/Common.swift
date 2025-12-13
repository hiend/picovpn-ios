import Foundation
import Network
import LibXray

public enum Common {
    public static let packageName = "me.lsong.picovpn"
    public static let groupName = "group.\(packageName)"
    public static let tunnelName = "\(packageName).tunnel"
    
    public static let containerURL: URL = {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
            fatalError("无法加载共享文件路径")
        }
        let fileManager = FileManager.default
        let directories = [
            url.appendingPathComponent("logs"),
            url.appendingPathComponent("datasets")
        ]
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                    // print("Created directory: \(directory.path)")
                } catch {
                    print("Error creating directory \(directory.path): \(error)")
                }
            }
        }
        return url
    }()
    
    public static let logPath = containerURL.appendingPathComponent("logs")
    public static let configPath = containerURL.appendingPathComponent("config.json")
    public static let datasetsPath = containerURL.appendingPathComponent("datasets")
    public static let errorLogPath = logPath.appendingPathComponent("error.log").path
    public static let accessLogPath = logPath.appendingPathComponent("access.log").path
}

// MARK: - LibXray Wrapper Functions

public func XraySetEnv(_ key: String, _ value: String) {
    // Environment setting is now handled differently
}

public func XrayStart(_ configPath: String) {
    do {
        let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let base64Config = configData.base64EncodedString()
        _ = CGoRunXray(strdup(base64Config))
    } catch {
        print("Failed to load config: \(error)")
    }
}

public func XrayStop() {
    _ = CGoStopXray()
}

public func XrayVersion() -> String {
    if let version = CGoXrayVersion() {
        return String(cString: version)
    }
    return "unknown"
}

public func XrayConvertXrayJsonToShareLinks(_ json: String) -> String {
    let base64 = json.data(using: .utf8)?.base64EncodedString() ?? ""
    if let result = CGOConvertXrayJsonToShareLinks(strdup(base64)) {
        let base64Result = String(cString: result)
        if let data = Data(base64Encoded: base64Result),
           let decoded = String(data: data, encoding: .utf8) {
            return decoded
        }
    }
    return ""
}

public func XrayConvertShareLinksToXrayJson(_ shareLinks: String) -> String {
    let base64 = shareLinks.data(using: .utf8)?.base64EncodedString() ?? ""
    if let result = CGoConvertShareLinksToXrayJson(strdup(base64)) {
        let base64Result = String(cString: result)
        if let data = Data(base64Encoded: base64Result),
           let decoded = String(data: data, encoding: .utf8) {
            return decoded
        }
    }
    return ""
}

public func XrayGetFreePort() -> Int {
    if let result = CGoGetFreePorts(1) {
        let resultStr = String(cString: result)
        if let data = resultStr.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ports = json["ports"] as? [Int],
           let port = ports.first {
            return port
        }
    }
    return 0
}

public func XrayLoadGeoData(_ path: String, _ type: String) -> String {
    let request = "{\"path\":\"\(path)\",\"type\":\"\(type)\"}"
    let base64 = request.data(using: .utf8)?.base64EncodedString() ?? ""
    if let result = CGoReadGeoFiles(strdup(base64)) {
        return String(cString: result)
    }
    return "{}"
}
