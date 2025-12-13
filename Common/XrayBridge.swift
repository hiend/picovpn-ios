//
//  XrayBridge.swift
//  PicoVPN
//
//  Swift wrapper for LibXray C functions
//

import Foundation
import LibXray

// Wrapper functions to provide the old API using new CGo functions
func XraySetEnv(_ key: String, _ value: String) {
    // Environment setting is now handled differently in the new version
    // We'll handle this via config instead
}

func XrayStart(_ configPath: String) {
    do {
        let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let base64Config = configData.base64EncodedString()
        _ = CGoRunXray(strdup(base64Config))
    } catch {
        print("Failed to load config: \(error)")
    }
}

func XrayStop() {
    _ = CGoStopXray()
}

func XrayVersion() -> String {
    if let version = CGoXrayVersion() {
        return String(cString: version)
    }
    return "unknown"
}

func XrayConvertXrayJsonToShareLinks(_ json: String) -> String {
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

func XrayConvertShareLinksToXrayJson(_ shareLinks: String) -> String {
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

func XrayGetFreePort() -> Int {
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

func XrayLoadGeoData(_ path: String, _ type: String) -> String {
    let request = "{\"path\":\"\(path)\",\"type\":\"\(type)\"}"
    let base64 = request.data(using: .utf8)?.base64EncodedString() ?? ""
    if let result = CGoReadGeoFiles(strdup(base64)) {
        return String(cString: result)
    }
    return "{}"
}
