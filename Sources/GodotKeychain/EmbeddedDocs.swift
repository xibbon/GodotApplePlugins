#if os(macOS)
import SwiftGodotRuntime

func loadEmbeddedKeychainDocs() {
    _ = loadEmbeddedKeychainDocsOnce
}

private let loadEmbeddedKeychainDocsOnce: Void = {
    [
        PackageResources.Keychain_xml,
    ].forEach(EditorInterop.loadHelp(buffer:))
}()
#endif
