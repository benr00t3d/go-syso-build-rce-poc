# Go `.syso` build-host execution reproduction

Private coordinated-disclosure repository for GO-F0003.

A downloaded Go module can carry serialized `cgo_ldflag` directives inside a
Go compiler object named as a `.syso` file. `cmd/go` packs the file without
applying its cgo linker-flag allowlist, and `cmd/link` can pass the embedded
value to the host compiler driver during an ordinary build.

The retained reproduction demonstrates host-side execution before a target
executable is produced or run, including with `CGO_ENABLED=0` and when the
crafted module is only an indirect dependency.

## Start here

- [`poc/README.md`](poc/README.md): minimal local reproduction
- [`poc/generator/README.md`](poc/generator/README.md): deterministic carrier
  generation
- [`disclosure/REPORT.md`](disclosure/REPORT.md): technical report and impact
- [`disclosure/EMAIL.txt`](disclosure/EMAIL.txt): draft report email
- [`disclosure/FIX.patch`](disclosure/FIX.patch): tested candidate remediation

The PoC uses only a temporary local marker and a local module proxy. The
target executable is never run.

## Disclosure status

Keep this repository private until the Go Security team approves disclosure.
The current Playground production image is not claimed to be affected by this
exact chain because it does not contain a compatible host linker.
