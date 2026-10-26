#!/bin/sh
set -eu

go_bin=${1:-go}
poc_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work_root=$(mktemp -d "${TMPDIR:-/tmp}/go-f0003.XXXXXX")
marker=/tmp/go-syso-module-marker

cleanup() {
	status=$?
	rm -f -- "$marker"
	if [ "${KEEP_TMP:-0}" != 1 ]; then
		chmod -R u+w "$work_root" 2>/dev/null || true
		rm -rf -- "$work_root"
	else
		printf 'retained=%s\n' "$work_root"
	fi
	exit "$status"
}
trap cleanup EXIT HUP INT TERM

rm -f -- "$marker"
cp -R "$poc_root/consumer" "$work_root/consumer"
mkdir -p "$work_root/home" "$work_root/gocache" "$work_root/modcache" "$work_root/tmp"

"$go_bin" version
set +e
(
	cd "$work_root/consumer"
	HOME="$work_root/home" \
	GOCACHE="$work_root/gocache" \
	GOMODCACHE="$work_root/modcache" \
	TMPDIR="$work_root/tmp" \
	GOTOOLCHAIN=local \
	GOENV=off \
	GOWORK=off \
	GOPROXY="file://$poc_root/proxy" \
	GOSUMDB=off \
	CGO_ENABLED=0 \
	GOOS=linux \
	GOARCH=amd64 \
		"$go_bin" build -mod=mod -a -buildvcs=false -x -work -ldflags=-v \
		-o "$work_root/consumer-result" . \
		> "$work_root/build.stdout" 2> "$work_root/build.stderr"
)
build_status=$?
set -e

host_marker=no
if [ -f "$marker" ]; then
	host_marker=yes
fi

module_downloaded=no
if [ -f "$work_root/modcache/example.test/evil@v1.0.2/directive.syso" ]; then
	module_downloaded=yes
fi

printf 'build_status=%s\n' "$build_status"
printf 'host_marker=%s\n' "$host_marker"
printf 'module_downloaded=%s\n' "$module_downloaded"

if [ "$host_marker" != yes ] || [ "$module_downloaded" != yes ]; then
	printf 'reproduction failed; last build diagnostics:\n' >&2
	tail -n 20 "$work_root/build.stderr" >&2
	exit 1
fi
