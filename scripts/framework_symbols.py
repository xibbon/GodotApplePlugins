#!/usr/bin/env python3
"""Generate, package, and check framework debug symbols."""

import argparse
from pathlib import Path
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile


def output(*args):
    return subprocess.check_output(args, text=True)


def binary(framework):
    for relative in ("Info.plist", "Resources/Info.plist"):
        info = framework / relative
        if info.is_file():
            with info.open("rb") as stream:
                name = plistlib.load(stream)["CFBundleExecutable"]
            return framework / name
    raise ValueError(f"Framework Info.plist is missing: {framework}")


def uuids(path):
    result = dict(re.findall(r"UUID: ([\w-]+) \(([^)]+)\)",
                            output("xcrun", "dwarfdump", "--uuid", str(path))))
    if not result:
        raise ValueError(f"No build UUIDs: {path}")
    return result


def verify(framework, symbols):
    expected = uuids(binary(framework))
    if expected != uuids(symbols):
        raise ValueError(f"dSYM UUIDs do not match {framework}: {symbols}")
    for arch in expected.values():
        debug_info = output("xcrun", "dwarfdump", f"--arch={arch}",
                            "--debug-info", "--recurse-depth=0", str(symbols))
        if "DW_TAG_compile_unit" not in debug_info:
            raise ValueError(f"dSYM has no debug information for {arch}: {symbols}")
    print(f"Verified dSYM: {symbols}", flush=True)


def symbol_candidates(framework):
    name = binary(framework).name + ".framework.dSYM"
    return [framework.with_name(framework.name + ".dSYM"),
            framework.parent.parent / name,
            framework.parent / "dSYMs" / name]


def find_symbols(framework, roots, allow_missing):
    for candidate in symbol_candidates(framework):
        if candidate.is_dir():
            verify(framework, candidate)
            return candidate

    # Xcode may leave a binary dependency's symbols in its source XCFramework.
    name = binary(framework).name + ".framework.dSYM"
    expected = uuids(binary(framework))
    for root in roots:
        for candidate in root.glob(f"**/{name}"):
            if uuids(candidate) == expected:
                verify(framework, candidate)
                return candidate
    message = f"No matching dSYM for {framework}"
    if not allow_missing:
        raise ValueError(message)
    print(f"WARNING: {message}. Obtain symbols from the original dependency build.",
          file=sys.stderr, flush=True)
    return None


def generate(framework):
    # Run this after relinking, before the object and LTO files are removed.
    destination = framework.with_name(framework.name + ".dSYM")
    expected = uuids(binary(framework))
    # Xcode can strip the debug map after it writes the dSYM. Keep that dSYM
    # when its UUIDs still match the final binary.
    for candidate in symbol_candidates(framework):
        if candidate.is_dir() and uuids(candidate) == expected:
            verify(framework, candidate)
            if candidate != destination:
                if destination.exists():
                    shutil.rmtree(destination)
                shutil.copytree(candidate, destination, symlinks=True)
            return
    with tempfile.TemporaryDirectory(dir=framework.parent) as temporary:
        symbols = Path(temporary) / destination.name
        subprocess.run(["xcrun", "dsymutil", "--verify", str(binary(framework)),
                        "-o", str(symbols)], check=True)
        verify(framework, symbols)
        if destination.exists():
            shutil.rmtree(destination)
        shutil.move(str(symbols), destination)


def verify_package(path, allow_missing):
    if path.suffix != ".xcframework":
        find_symbols(path, [], allow_missing)
        return
    with (path / "Info.plist").open("rb") as stream:
        libraries = plistlib.load(stream)["AvailableLibraries"]
    for library in libraries:
        slice_path = path / library["LibraryIdentifier"]
        framework = slice_path / library["LibraryPath"]
        symbols_path = library.get("DebugSymbolsPath")
        if not symbols_path:
            if not allow_missing:
                raise ValueError(f"DebugSymbolsPath is missing: {framework}")
            find_symbols(framework, [], True)
            continue
        symbols = slice_path / symbols_path / (binary(framework).name + ".framework.dSYM")
        verify(framework, symbols)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    generate_parser = commands.add_parser("generate", help="Generate symbols after the final link")
    generate_parser.add_argument("framework", type=Path)
    package_parser = commands.add_parser("xcframework", help="Package frameworks with their symbols")
    package_parser.add_argument("destination", type=Path)
    package_parser.add_argument("frameworks", nargs="+", type=Path)
    package_parser.add_argument("--xcodebuild", default="xcodebuild")
    copy_parser = commands.add_parser("copy", help="Copy symbols beside a standalone framework")
    copy_parser.add_argument("framework", type=Path)
    copy_parser.add_argument("destination", type=Path)
    verify_parser = commands.add_parser("verify", help="Check packaged UUIDs and debug information")
    verify_parser.add_argument("paths", nargs="+", type=Path)
    for subparser in (package_parser, copy_parser, verify_parser):
        subparser.add_argument("--allow-missing-symbols", action="store_true",
                               help="Report missing vendor symbols without stopping")
    for subparser in (package_parser, copy_parser):
        subparser.add_argument("--search-root", action="append", type=Path, default=[])
    args = parser.parse_args()

    if args.command == "generate":
        generate(args.framework.resolve())
    elif args.command == "xcframework":
        command = shlex.split(args.xcodebuild) + ["-create-xcframework"]
        for framework in args.frameworks:
            framework = framework.resolve()
            symbols = find_symbols(framework, args.search_root, args.allow_missing_symbols)
            command += ["-framework", str(framework)]
            if symbols:
                command += ["-debug-symbols", str(symbols.resolve())]
        command += ["-output", str(args.destination.resolve())]
        subprocess.run(command, check=True)
        verify_package(args.destination, args.allow_missing_symbols)
    elif args.command == "copy":
        symbols = find_symbols(args.framework.resolve(), args.search_root,
                               args.allow_missing_symbols)
        if args.destination.exists():
            shutil.rmtree(args.destination)
        if symbols:
            shutil.copytree(symbols, args.destination, symlinks=True)
    elif args.command == "verify":
        for path in args.paths:
            verify_package(path, args.allow_missing_symbols)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
