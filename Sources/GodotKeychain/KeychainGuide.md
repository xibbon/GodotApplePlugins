# Using the Keychain API with Godot

This is a guide on using Apple's Keychain Services to persist small secrets
(auth tokens, refresh tokens, account identifiers) across app reinstalls,
via this Godot addon.

`Keychain` stores values as generic passwords (`kSecClassGenericPassword`)
scoped to your app's bundle identifier, with `kSecAttrAccessibleAfterFirstUnlock`.
No entitlements are required for this per-app scope — Keychain Sharing
entitlements are only needed if you want an access group shared across
multiple apps from the same team, which this binding does not expose.

## Usage

```gdscript
var keychain := Keychain.new()

func _save_token(token: String) -> void:
    if not keychain.set_value("auth_token", token):
        print("Failed to write to keychain")

func _load_token() -> String:
    return keychain.get_value("auth_token")

func _clear_token() -> void:
    keychain.delete_value("auth_token")
```

`get_value()` returns an empty string if the key does not exist or the
device has no Keychain support (e.g. running on a platform stub). Always
check for an empty result before treating a missing value as an error.

Unlike file-based storage, Keychain entries survive a full delete +
reinstall of the app, since they are not stored inside the app's sandbox
container.
