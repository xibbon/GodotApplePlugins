"""Integration checks that use real Mach-O binaries and Xcode tools."""

from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/framework_symbols.py"


@unittest.skipUnless(sys.platform == "darwin", "Requires Xcode on macOS")
class FrameworkSymbolsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="framework-symbols-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.framework = self.root / "Example.framework"
        self.framework.mkdir()
        with (self.framework / "Info.plist").open("wb") as stream:
            plistlib.dump({"CFBundleExecutable": "Example",
                          "CFBundleIdentifier": "org.example.symbols",
                          "CFBundlePackageType": "FMWK"}, stream)
        self.compile()

    def compile(self, value=1, debug=True):
        source = self.root / "example.c"
        source.write_text(f"int example(void) {{ return {value}; }}\n")
        obj = self.root / "example.o"
        subprocess.run(["xcrun", "clang", "-g" if debug else "-g0", "-c",
                        str(source), "-o", str(obj)], check=True)
        subprocess.run(["xcrun", "clang", "-dynamiclib", str(obj),
                        "-install_name", "@rpath/Example.framework/Example",
                        "-o", str(self.framework / "Example")], check=True)

    def run_tool(self, *arguments, success=True):
        result = subprocess.run([sys.executable, str(SCRIPT), *map(str, arguments)],
                                text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_regenerate_after_relink(self):
        self.run_tool("generate", self.framework)
        self.compile(value=2)
        result = self.run_tool("verify", self.framework, success=False)
        self.assertIn("UUIDs do not match", result.stderr)
        self.run_tool("generate", self.framework)
        self.run_tool("verify", self.framework)

    def test_xcframework_contains_matching_symbols(self):
        self.run_tool("generate", self.framework)
        destination = self.root / "Example.xcframework"
        self.run_tool("xcframework", destination, self.framework)
        self.run_tool("verify", destination)
        with (destination / "Info.plist").open("rb") as stream:
            library = plistlib.load(stream)["AvailableLibraries"][0]
        self.assertIn("DebugSymbolsPath", library)

    def test_keep_matching_xcode_symbols_after_strip(self):
        self.run_tool("generate", self.framework)
        package_frameworks = self.root / "PackageFrameworks"
        package_frameworks.mkdir()
        self.framework = self.framework.rename(package_frameworks / self.framework.name)
        subprocess.run(["xcrun", "strip", "-S", str(self.framework / "Example")], check=True)
        self.run_tool("generate", self.framework)
        self.run_tool("verify", self.framework)

    def test_missing_vendor_symbols_are_explicit(self):
        self.run_tool("verify", self.framework, success=False)
        result = self.run_tool("verify", self.framework, "--allow-missing-symbols")
        self.assertIn("WARNING: No matching dSYM", result.stderr)

    def test_empty_symbols_are_rejected(self):
        self.compile(debug=False)
        result = self.run_tool("generate", self.framework, success=False)
        self.assertIn("no debug information", result.stderr)


if __name__ == "__main__":
    unittest.main()
