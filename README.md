# cmd/go `.syso` linker-flag validation bypass

A precompiled Go object named as a `.syso` file can carry serialized
`cgo_ldflag` records past `cmd/go`'s source-level checks. During an ordinary
`go build`, `cmd/link` forwards those values to the host compiler driver.

This repository contains two focused reproductions:

1. a macOS visual demonstration that opens Calculator during `go build`; and
2. a Linux local-module-proxy test proving that a downloaded dependency can
   reach the same build-host execution path.

## macOS visual demonstration

Requirements: an Apple-silicon Mac, Apple Command Line Tools, and Go on
`PATH`. The module pins Go 1.27.3.

```sh
DEMO_ROOT="$(mktemp -d /tmp/go-syso-calculator.XXXXXX)"
gh repo clone benr00t3d/go-syso-build-rce-poc "$DEMO_ROOT/repo"
cd "$DEMO_ROOT/repo"
go build
```

Calculator opens while the Go linker processes the crafted package. The build
then fails intentionally because the demonstration library is not a real LTO
implementation. No target executable is produced or run.

For the positive case and its matched source-level control, run:

```sh
./verify-macos.sh
```

The expected summary is:

```text
positive_marker=yes
positive_target=no
calculator_launch_receipt=yes
control_rejected=yes
control_marker=no
verdict=VULNERABLE
```

The demonstration library can be rebuilt from the checked-in source with
`plugin/build-macos.sh`.

## Downloaded-module reproduction

The canonical reachability test is under [`poc/`](poc/README.md). It uses a
local file module proxy and an empty module cache. The consumer downloads the
crafted dependency during a normal build. Its only effect is a temporary
marker that the verifier removes on exit.

On Linux amd64 with an affected Go toolchain and GCC:

```sh
cd poc
./verify.sh /path/to/affected/go
```

Expected result:

```text
build_status=1
host_marker=yes
module_downloaded=yes
```

## Files to review

- [`disclosure/REPORT.md`](disclosure/REPORT.md): technical report and root cause
- [`disclosure/EMAIL.md`](disclosure/EMAIL.md): report email
- [`disclosure/FIX.patch`](disclosure/FIX.patch): candidate remediation
- [`verify-macos.sh`](verify-macos.sh): macOS positive and negative control
- [`poc/verify.sh`](poc/verify.sh): downloaded-module reproduction
- [`poc/generator/`](poc/generator): deterministic `.syso` construction

`SHA256SUMS` covers the retained reproduction files. Full historical build
transcripts remain available in repository commit
`dd27c5ff7fcc51ef32d83c6abe065be62b8280a6`.

Send vulnerability discussion to `security@golang.org` rather than opening a
public Go issue.
