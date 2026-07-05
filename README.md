![banner](./doctools/GodotApplePlugins.webp)

Godot Plugins for deep Apple platform integration across macOS, iOS, and visionOS.

<p align="center">
<strong>
	<a href="https://migueldeicaza.github.io/GodotApplePlugins/index.html">API Documentation</a> | Download: <a href="https://godotengine.org/asset-library/asset/4552">Godot Asset Library</a> | Download: <a href="https://github.com/migueldeicaza/GodotApplePlugins/releases">GitHub Releases</a> | Discord <a href="https://discord.gg/bHAsTYaCZM">#godot-apple-plugins</a>
</strong>
</p>

You can get a ready-to-use binary from the "releases" tab, just drag the contents  into 
your addons directory.   You can start testing right away  on a Mac project, and for iOS, 
export your iOS project and run.

This add-on currently includes comprehensive support for:

* GameCenter [GameCenter Integration Guide](Sources/GodotGameCenter/GameCenterGuide.md)
* StoreKit2 [StoreKit Integration Guide](Sources/GodotStoreKit/StoreKitGuide.md)
* Sign-in with Apple [AuthenticationServices Integration Guide](Sources/GodotAuthenticationServices/AuthenticationServicesGuide.md)
* AppleFilePicker: allow your application to invoke the file system picker.
* iCloud key-value storage [Foundation Integration Guide](Sources/GodotFoundation/FoundationGuide.md)
* ARKit [ARKit Integration Guide](Sources/GodotARKit/ARKitGuide.md)
* CoreMotion [CoreMotion Integration Guide](Sources/GodotCoreMotion/CoreMotionGuide.md)
* Keychain [Keychain Integration Guide](Sources/GodotKeychain/KeychainGuide.md)

Notice that this package has multiple split libraries, if you are not
using them, you can save space (and a roundtrip answering Apple's
questions) by not including them (like "Why are you calling ARKit if
your app has no AR capabilities").

The release contains both binaries for MacOS as dynamic libraries and
an iOS xcframework compiled with the "Mergeable Library" feature.
This means that for Debug builds, your Godot game contains a dynamic
library (about 10 megs at the time of this writing) that does not need
to be copied on every build speeding your development, but you can
switch to "Release Mode" and set "Create Merged Binary" to "Manual"
and you will further reduce the size of your executable (about 1.7
megs at the time of this writing).

# Requirements

iOS 17.0, macOS 14.0, visionOS 1.0

The addon also works on non-Apple platforms (Windows, Linux) using empty stubs so
that your project can reference the API without compile errors. See the
[Stub Generator](StubGenerator.md) documentation for details on generating
stubs for other targets.

# API Design

The API surfaced by this add-ons is to be as close to possible to the Apple APIs
(classes, methods names, enumerations) and to avoid attempting to provide an
abstraction over them - as these tend to have impedance mismatches.  

In place of Apple delegate's pattern, I use Godot's callbacks - and I surfaced
properties and methods use snake-case instead of Apple's camelCase, but beyond
that, the mapping should be almost identical.

Both GameCenter and AuthenticationServices APIs use class names that are 1:1
mappings to Apple's APIs as they use 2-letter namespaces (GK, AS) and they are
not likely to conflicth with your code.   For the StoreKit API, I chose to
change the names as these APIs use terms that are too general (Store, Product)
and could clash with your own code.

# Size

This addon adds 2.5 megabytes to your executable for release builds, but it is
larger during development to speed up your development.

Plain Godot Export, empty:

```
Debug:   104 MB
Release:  93 MB
```

Godot Export, adding GodotApplePlugins with mergeable libraries:

```
Debug:   107 MB
Release:  95 MB
```

If you manually disable mergeable libraries and build your own addon:

```
Debug:   114 MB
Release: 105 MB
```

# Credits

The "AuthenticationServices" code was derived from [Dragos Daian's/
Nirmal Ac's](https://github.com/appsinacup/godot-apple-login) binding and 
Xogot's own use.   Dragos also provided extensive technical guidance on 
putting together this addon for distribution.   Thank you!
