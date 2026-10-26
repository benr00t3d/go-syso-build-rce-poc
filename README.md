# Go `.syso` build-host execution

This repository reproduces GO-F0003, a `cmd/go` validation bypass. A Go
compiler object named as a `.syso` file can carry serialized `cgo_ldflag`
records past the source-level linker flag checks. During an ordinary
`go build`, `cmd/link` forwards those records to the host compiler driver.

The Apple-silicon demo makes the build-host effect visible by opening
Calculator. It was independently verified on a clean macOS 15 ARM64 runner
with Go 1.27.3 and Apple Clang 17.

## macOS Calculator demo

Requirements: an Apple-silicon Mac, Apple Command Line Tools, Go on `PATH`,
and access to download the pinned Go 1.27.3 toolchain if it is not installed.

```sh
DEMO_ROOT="$(mktemp -d /tmp/go-syso-calculator.XXXXXX)"
gh repo clone benr00t3d/go-syso-build-rce-poc "$DEMO_ROOT/repo"
code --new-window "$DEMO_ROOT/repo"
```

VS Code first opens an unfamiliar folder in Restricted Mode. Once the folder
is trusted, its folder-open demo task runs `./verify-macos.sh`. Calculator
opens while the Go linker is processing the crafted package. The expected
terminal summary is:

```text
positive_status=1
positive_marker=yes
positive_target=no
calculator_launch_receipt=yes
control_status=1
control_rejected=yes
control_marker=no
verdict=VULNERABLE
```

The same verifier can be run without VS Code:

```sh
./verify-macos.sh
```

Set `KEEP_TMP=1` to retain the complete build transcripts.

The VS Code folder-open task is only a recorder-friendly demo harness. The
security issue does not depend on VS Code, the Go extension, or a task file.
The actual trigger is `go build`. The separate module-proxy reproduction under
`poc/` proves the downloaded and indirect-dependency cases with an empty module
cache.

## What the macOS control proves

The crafted `.syso` serializes these host-linker options:

```text
-Wl,-ld_classic
-Wl,-lto_library,arm64-cfg/libLTO.dylib
```

Apple's classic linker loads the supplied LTO library and reaches its
constructor before rejecting it as an invalid LTO implementation. The target
program is never produced or run. When the identical options appear in normal
`#cgo LDFLAGS` source, Go rejects them before the linker starts and Calculator
does not open.

The visual demo keeps its dylib inside this checkout at a fixed relative path.
It demonstrates the macOS build-host primitive. The `poc/` reproduction is the
canonical proof that a module fetched over the module protocol can trigger the
same validation bypass without controlling the consumer's build command.

## Report package

- [`disclosure/REPORT.md`](disclosure/REPORT.md): report, root cause, impact,
  controls, and suggested fix
- [`disclosure/EMAIL.txt`](disclosure/EMAIL.txt): concise report email
- [`disclosure/FIX.patch`](disclosure/FIX.patch): tested candidate remediation
- [`disclosure/evidence/`](disclosure/evidence): pinned build receipts
- [`poc/README.md`](poc/README.md): minimal downloaded-module reproduction
- [`poc/generator/README.md`](poc/generator/README.md): deterministic carrier
  generation

Keep the repository private until the Go Security team approves disclosure.
