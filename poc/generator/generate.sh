#!/bin/sh
set -eu

go_bin=${1:-go}
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
out=${2:-$(mktemp -d "${TMPDIR:-/tmp}/go-f0003-generator.XXXXXX")}

mkdir -p "$out/extract" "$out/home" "$out/gocache"
HOME="$out/home" GOCACHE="$out/gocache" GOTOOLCHAIN=local GOENV=off \
	"$go_bin" tool compile -pack -p example.test/evil \
	-o "$out/payload.a" "$root/_cgo_payload.go"
(
	cd "$out/extract"
	"$go_bin" tool pack x "$out/payload.a" _go_.o
)
HOME="$out/home" GOCACHE="$out/gocache" GOTOOLCHAIN=local GOENV=off \
	"$go_bin" run "$root/zero-fingerprint.go" \
	"$out/extract/_go_.o" "$out/directive.syso"

sha256sum "$out/payload.a" "$out/extract/_go_.o" "$out/directive.syso"
printf 'output=%s\n' "$out"
