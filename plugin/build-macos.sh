#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
clang=$(xcrun --find clang)
sdk=$(xcrun --show-sdk-path)
output="$root/arm64-cfg/libLTO.dylib"

"$clang" -isysroot "$sdk" -dynamiclib -fPIC -arch arm64 \
	-Wl,-install_name,@rpath/libLTO.dylib \
	-Wl,-compatibility_version,1.0.0 \
	-Wl,-current_version,5100.3.34 \
	"$root/plugin/calculator_demo.c" "$root/plugin/lto_api_stubs.c" \
	-o "$output"
codesign --force --sign - "$output"
file "$output"
shasum -a 256 "$output"
