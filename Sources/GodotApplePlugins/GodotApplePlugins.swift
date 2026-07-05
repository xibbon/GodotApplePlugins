import SwiftGodotRuntime
import GodotApplePluginsARKit
import GodotApplePluginsAuthenticationServices
import GodotApplePluginsAVFoundation
import GodotApplePluginsCoreMotion
import GodotApplePluginsFoundation
import GodotApplePluginsGameCenter
import GodotApplePluginsKeychain
import GodotApplePluginsStoreKit

private let godotApplePluginsMinimumInitializationLevel: ExtensionInitializationLevel = {
    [
        godotApplePluginsAVFoundationMinimumInitializationLevel,
        godotApplePluginsFoundationMinimumInitializationLevel,
        godotApplePluginsGameCenterMinimumInitializationLevel,
        godotApplePluginsStoreKitMinimumInitializationLevel,
        godotApplePluginsAuthenticationServicesMinimumInitializationLevel,
        godotApplePluginsARKitMinimumInitializationLevel,
        godotApplePluginsCoreMotionMinimumInitializationLevel,
        godotApplePluginsKeychainMinimumInitializationLevel,
    ].min(by: { $0.rawValue < $1.rawValue }) ?? .scene
}()

public func godotApplePluginsInitialize(level: ExtensionInitializationLevel) {
    godotApplePluginsAVFoundationInitialize(level: level)
    godotApplePluginsFoundationInitialize(level: level)
    godotApplePluginsGameCenterInitialize(level: level)
    godotApplePluginsStoreKitInitialize(level: level)
    godotApplePluginsAuthenticationServicesInitialize(level: level)
    godotApplePluginsARKitInitialize(level: level)
    godotApplePluginsCoreMotionInitialize(level: level)
    godotApplePluginsKeychainInitialize(level: level)
}

public func godotApplePluginsDeinitialize(level: ExtensionInitializationLevel) {
    godotApplePluginsKeychainDeinitialize(level: level)
    godotApplePluginsCoreMotionDeinitialize(level: level)
    godotApplePluginsARKitDeinitialize(level: level)
    godotApplePluginsAuthenticationServicesDeinitialize(level: level)
    godotApplePluginsStoreKitDeinitialize(level: level)
    godotApplePluginsGameCenterDeinitialize(level: level)
    godotApplePluginsFoundationDeinitialize(level: level)
    godotApplePluginsAVFoundationDeinitialize(level: level)
}

@_cdecl("godot_apple_plugins_start")
public func godotApplePluginsStart(interface: OpaquePointer?, library: OpaquePointer?, extension: OpaquePointer?) -> UInt8 {
    guard let interface, let library, let `extension` else {
        print("Error: Not all parameters were initialized.")
        return 0
    }

    initializeSwiftModule(
        interface,
        library,
        `extension`,
        initHook: godotApplePluginsInitialize,
        deInitHook: godotApplePluginsDeinitialize,
        minimumInitializationLevel: godotApplePluginsMinimumInitializationLevel
    )
    return 1
}
