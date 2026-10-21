# Maintainers Guide

## Debug symbols

`make split-build` generates a dSYM for each plugin after its final link step.
Keep the object and LTO files until this step completes. A relink can change the
binary UUID and invalidate the dSYM that Xcode generated earlier.

`make split-dist` includes matching dSYMs in each iOS XCFramework. It also copies
macOS dSYMs beside the standalone frameworks. Packaging fails if plugin symbols
are missing, empty, or have different UUIDs. The release workflow checks these
files and uploads the package as an Actions artifact before notarization.

The pinned `SwiftGodotRuntime` binary does not include its dSYMs. Packaging reports
this as a warning. It can include matching runtime dSYMs from the build products
or cached dependency artifacts when the dependency provides them. To resolve the
runtime warning, obtain its original dSYMs, or release a new runtime binary with
its matching dSYMs and update the dependency. Symbols from another build cannot
be used with the current binary.

For an App Store upload, keep the dSYMs in the app archive's `dSYMs` directory,
outside the `.app` bundle. Godot preserves the plugin XCFrameworks when it exports
the Xcode project. Check that the app archive contains their matching symbols
before upload. Keep that archive for crash reports.

To check a packaged framework or XCFramework, run:

```sh
python3 scripts/framework_symbols.py verify /path/to/Example.xcframework
python3 -m unittest discover -s tests -p 'test_framework_symbols.py'
```

## Documentation

To build the API documentation locally, run:

```sh
make -C doctools html
```

The local docs tool defaults to `$(HOME)/cvs/master-godot/doc/classes` when that exists, and falls back to `$(HOME)/cvs/master-godot/editor/doc/classes` for older checkouts. You can override that path, or the HTML output directory, when needed:

```sh
make -C doctools html GODOT_DOCS_SOURCE=/path/to/godot/doc/classes
make -C doctools html GODOT_DOCS_SOURCE=/path/to/godot/doc/classes HTML_OUTPUT=../site
```

To publish the generated docs to the `docs` branch without switching your current checkout, run:

```sh
make deploy-docs
```

This builds the site into a temporary directory, updates the `docs/` folder on the `docs` branch through a temporary `git worktree`, commits only when the generated output changed, and pushes to `origin/docs`. The repository Pages source should be set to the `docs` branch and the `/docs` folder.
