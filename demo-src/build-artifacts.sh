#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
go_bin=${GO_BIN:-go}
clang_bin=${CLANG_BIN:-clang}
expected_go=${EXPECTED_GO:-go1.27.3}
work=$(mktemp -d "${TMPDIR:-/tmp}/go-syso-macos-artifacts.XXXXXX")

actual_go=$("$go_bin" env GOVERSION)
if [ "$actual_go" != "$expected_go" ]; then
	printf 'error: artifact generation requires %s (got %s)\n' \
		"$expected_go" "$actual_go" >&2
	exit 1
fi

mkdir -p "$work/extract" "$work/home" "$work/gocache"
HOME="$work/home" GOCACHE="$work/gocache" GOENV=off GOTOOLCHAIN=local \
GOOS=darwin GOARCH=arm64 \
	"$go_bin" tool compile -pack \
	-p example.test/go-syso-macos-demo/payload \
	-o "$work/payload.a" "$root/demo-src/_cgo_payload.go"
(
	cd "$work/extract"
	"$go_bin" tool pack x "$work/payload.a" _go_.o
)
HOME="$work/home" GOCACHE="$work/gocache" GOENV=off GOTOOLCHAIN=local \
	"$go_bin" run "$root/poc/generator/zero-fingerprint.go" \
	"$work/extract/_go_.o" "$root/payload/directive_darwin_arm64.syso"

"$clang_bin" -target arm64-apple-darwin -flto -c \
	"$root/demo-src/empty.c" -o "$root/payload/unknown_darwin_arm64.syso"

file "$root/payload/directive_darwin_arm64.syso" \
	"$root/payload/unknown_darwin_arm64.syso"
if command -v sha256sum >/dev/null 2>&1; then
	sha256sum "$root/payload/directive_darwin_arm64.syso" \
		"$root/payload/unknown_darwin_arm64.syso"
else
	shasum -a 256 "$root/payload/directive_darwin_arm64.syso" \
		"$root/payload/unknown_darwin_arm64.syso"
fi
printf 'work=%s\n' "$work"
