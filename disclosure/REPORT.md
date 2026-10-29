# cmd/go: downloaded `.syso` bypasses cgo linker flag validation

Date: 2026-10-26

Reporter: Robert Prast

Repository: https://github.com/benr00t3d/go-syso-build-rce-poc

## Summary

A downloaded Go module can put a precompiled Go object in a `.syso` file. The
Go command adds that file to the package archive without applying the cgo
linker flag allowlist. The Go linker then reads serialized `cgo_ldflag`
directives from the object and passes them to the host C compiler driver.

The attached reproduction executes a local marker command during an ordinary
`go build`, before the target executable is produced or run. It works with
`CGO_ENABLED=0` and the dependency does not import `C`.

## Affected versions

I reproduced the host-side effect with unmodified toolchains:

```text
go1.26.10
go1.27.3
go1.28-devel at deab4989e6586057f154e164ab92940b79b8ed19
```

The end-to-end reproduction is pinned to Go 1.27.3 on Linux amd64 with GCC
15.2.0. I repeated it using the official `go1.27.3.linux-amd64.tar.gz`
download. Its SHA-256 matched Go's live download manifest:

```text
65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40
```

## Reproduction

The `poc` directory contains a consumer and a local module proxy. The module
zip is 625 bytes uncompressed and contains one ordinary Go file plus two
`.syso` files. The only host-side effect is a temporary file under `/tmp`,
removed by the script on exit.

```sh
cd poc
./verify.sh /path/to/go1.27.3/bin/go
```

Observed result:

```text
build_status=1
host_marker=yes
module_downloaded=yes
```

The final link failure is expected. The host marker exists before there is a
target executable, and the script never runs the target.

I also served the same proxy over loopback HTTP to an empty module cache. The
official Go toolchain requested and accepted all three module-proxy resources:

```text
GET /example.test/evil/@v/v1.0.2.zip
GET /example.test/evil/@v/v1.0.2.mod
GET /example.test/evil/@v/v1.0.2.info
```

That run produced:

```text
official_archive_sha256=yes
build_status=1
host_marker=yes
module_downloaded=yes
target_executable=no
http_gets=3
```

I repeated the build with the crafted module only as an indirect dependency.
The root program imported a local wrapper and contained no import of the
crafted module. The wrapper required it normally. A fresh module cache fetched
the indirect dependency over HTTP and the same host-side effect occurred:

```text
transitive_build_status=1
root_direct_import=no
transitive_host_marker=yes
transitive_module_downloaded=yes
transitive_target_executable=no
```

## macOS visual reproduction

I also reproduced the same validation bypass on clean Apple-silicon runners
and made the build-host effect visible with Calculator. The pinned matrix was:

```text
macOS 15.7.9 (24G830), arm64
go version go1.27.3 darwin/arm64
Apple clang 17.0.0 (clang-1700.0.13.5)

macOS 27.0.1 (26A434), arm64
go version go1.27.3 darwin/arm64
Apple clang 21.0.0 (clang-2100.3.34.2)
```

The Darwin carrier serializes two options that normal cgo source cannot use:

```text
-Wl,-ld_classic
-Wl,-lto_library,arm64-cfg/libLTO.dylib
```

The second `.syso` is LLVM bitcode, which both forces external linking and
causes the Apple linker to use the supplied `libLTO.dylib`. On macOS 15 the
first option selects the classic linker. Xcode 27 removed that linker and
ignores `-ld_classic`, but its replacement linker still maps the library named
by `-lto_library`.

Xcode 27's linker directly imports 45 `lto_*` and `thinlto_*` symbols. dyld
binds those imports before it runs constructors. The demonstration library
therefore exports inert placeholders for that exact import surface. Its
constructor writes a marker and asks Launch Services to open Calculator. The
placeholders then make LTO processing fail safely, so no target executable is
produced or run.

Observed result:

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

The Xcode 27 linker transcript is:

```text
host link: "clang" ... "-Wl,-ld_classic" "-Wl,-lto_library,arm64-cfg/libLTO.dylib"
ld: warning: -ld_classic is no longer supported and will be ignored
ld: could not parse bitcode object file ... using libLTO version '(null)' ...
clang: error: linker command failed with exit code 1
```

The marker is written from the dylib constructor before that diagnostic. With
the identical options in ordinary `#cgo LDFLAGS`, the same toolchain instead
reports:

```text
invalid flag in #cgo LDFLAGS: -Wl,-ld_classic
```

The two-runner GitHub Actions receipt is run `40389859587` at commit
`17f0a5574a8b25ae465db3390992fb028071ed76`. Both jobs used the checked-in
dylib and produced `calculator_launch_receipt=yes`. The macOS verifier at the
repository root runs the same positive case and control.

The macOS demo keeps the dylib at a fixed path inside the checkout. The HTTP
module-proxy reproduction above is the canonical proof of downloaded and
indirect dependency reachability.

The decisive build transcript contains these events in order:

```text
go: downloading example.test/evil v1.0.2
go tool pack r ... ./directive.syso ./unknown.syso
loadinternal: cannot find runtime/cgo
host link: "gcc" ... "-wrapper" "/bin/sh,-c,touch /tmp/go-syso-module-marker" ...
```

## Root cause

At revision `deab4989e6586057f154e164ab92940b79b8ed19`:

1. `src/cmd/go/internal/work/exec.go:1036-1039` adds every selected `.syso`
   file to the package archive.
2. The cgo security backstop at `exec.go:3713-3785` scans generated
   `_cgo_*.go` source only. It does not inspect cgo records already serialized
   in a `.syso`.
3. `src/cmd/link/internal/ld/go.go:62-96` reads a cgo JSON section from a Go
   object. `go.go:274-279` appends each `cgo_ldflag` to the global host-linker
   flag list without revalidation.
4. `src/cmd/link/internal/ld/lib.go:2606-2617` skips package fingerprint
   consistency when the serialized fingerprint is zero. This lets the
   directive carrier coexist with the dependency's ordinary Go object.
5. A second unrecognized `.syso` sets `unknownObjFormat` at
   `lib.go:2532-2537`. `config.go:166-168` then selects external linking even
   when cgo is disabled.
6. `lib.go:1978-1981` appends the unchecked values to the host-linker argv,
   and `lib.go:2038-2041` executes it.

The Go source itself documents the macOS consequence. In
`src/cmd/go/internal/work/security.go`, `-lto_library` is listed separately in
`invalidLinkerFlags` because the linker loads and executes its next argument.

The `runtime/cgo` diagnostic does not stop the link before the host compiler
driver is invoked.

## Artifact construction

The carrier is reproducible with the affected Go toolchain. It does not
depend on guessing an address or corrupting process memory. The steps are:

1. Compile an `_cgo_`-named source file containing two `cgo_ldflag`
   directives with `go tool compile`.
2. Extract the compiler's `_go_.o` archive member.
3. Zero the eight-byte package fingerprint immediately after the documented
   `\x00go120ld` object magic.

The generator under `poc/generator` reproduced the disclosure artifact
byte-for-byte from the official Go 1.27.3 toolchain:

```text
fingerprint_offset=265
changed_bytes=8
matches_disclosure_fixture=yes
```

## Controls

- Putting the same flag in ordinary source-level `#cgo LDFLAGS` is rejected
  by the same official Go 1.27.3 archive as an invalid flag. It creates no
  marker.
- Keeping the normal nonzero fingerprint in the directive object produces a
  fingerprint mismatch and no host-side marker.
- The successful module has no `import "C"`. The source used to make the
  precompiled object is not present in the module zip.
- The indirect-dependency control confirms that the root application need not
  import the crafted package directly.
- The target build fails and no target executable runs, but the host marker is
  present.
- On macOS, the same serialized flags load the Calculator dylib, while the
  source-level control is rejected and creates no marker.

## Security impact

The Go security decisions explicitly classify "a malicious module can cause
go build to execute arbitrary code" as a PRIVATE-track vulnerability. A
malicious or compromised dependency can use this path to execute with the
developer or CI builder's privileges during an ordinary build on a host with
a compatible C compiler driver.

This is the same security boundary as CVE-2018-6574 and CVE-2023-29404. The
closest direct precedent is CVE-2023-29404, another cgo linker flag validation
bypass during a downloaded module build. NVD scored that issue 9.8 under
CVSS 3.1. I understand that the Go project does not assign or endorse CVSS
scores.

The demonstrated prerequisites are bounded and concrete:

- the dependency must be selected into a linked executable;
- the host must have a compatible C compiler driver available;
- the precompiled object must target the host's Go release and object header.

The attacker does not need control of environment variables, `CGO_ENABLED`,
the compiler path, or the build command. The reproduction sets `GOENV=off`,
uses an empty module cache, and sets `CGO_ENABLED=0`.

## Suggested fix

Reject Go compiler objects presented as `.syso` files before they are packed.
`.syso` files are system object files; a Go object in that position is the
untrusted path that carries pre-serialized cgo directives around cmd/go's
validation.

`FIX.patch` is a small candidate implementation and regression test. With the
patch applied:

```text
build_status=1
host_marker=no
rejection=yes
```

The existing `TestScript/cgo_syso_issue29253` test still passes with cgo
enabled, showing that ordinary native `.syso` support remains intact.

Defense in depth would also track the provenance of serialized cgo directives
and ensure every untrusted value is validated before host-linker execution.

## References

- https://go.dev/blog/path-security
- https://go.dev/wiki/InvalidFlag
- https://pkg.go.dev/vuln/GO-2023-1841
- https://pkg.go.dev/vuln/GO-2026-4871
- https://go.dev/doc/security/policy
- https://go.dev/doc/security/decisions

## Attribution

Robert Prast

## Historical receipts

The full raw build transcripts used while preparing this report are retained
in repository commit `dd27c5ff7fcc51ef32d83c6abe065be62b8280a6`. They were
removed from the current tree so the reproduction remains small and direct.
