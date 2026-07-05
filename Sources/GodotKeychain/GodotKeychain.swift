import SwiftGodotRuntime

private func makeGodotApplePluginsKeychainTypes() -> [ExtensionInitializationLevel: [Object.Type]] {
    do {
        return try [
            Keychain.self,
        ].prepareForRegistration()
    } catch {
        fatalError("Failed to prepare Keychain registrations: \(error)")
    }
}

private let godotApplePluginsKeychainTypes = makeGodotApplePluginsKeychainTypes()

public let godotApplePluginsKeychainMinimumInitializationLevel = minimumInitializationLevel(
    for: godotApplePluginsKeychainTypes
)

public func godotApplePluginsKeychainInitialize(level: ExtensionInitializationLevel) {
    godotApplePluginsKeychainTypes[level]?.forEach(register)
    if level == .editor {
#if os(macOS)
        loadEmbeddedKeychainDocs()
#endif
    }
}

public func godotApplePluginsKeychainDeinitialize(level: ExtensionInitializationLevel) {
    godotApplePluginsKeychainTypes[level]?.reversed().forEach(unregister)
}

@_cdecl("godot_apple_plugins_keychain_start")
public func godotApplePluginsKeychainStart(interface: OpaquePointer?, library: OpaquePointer?, extension: OpaquePointer?) -> UInt8 {
    guard let interface, let library, let `extension` else {
        print("Error: Not all parameters were initialized.")
        return 0
    }

    initializeSwiftModule(
        interface,
        library,
        `extension`,
        initHook: godotApplePluginsKeychainInitialize,
        deInitHook: godotApplePluginsKeychainDeinitialize,
        minimumInitializationLevel: godotApplePluginsKeychainMinimumInitializationLevel
    )
    return 1
}
