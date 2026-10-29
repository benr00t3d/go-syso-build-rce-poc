# Email to Go Security

To: `security@golang.org`

Subject: `cmd/go: downloaded .syso bypasses cgo linker-flag validation`

Hello Go Security Team,

I found a `cmd/go` validation bypass that lets a downloaded module execute code
on the build host during an ordinary `go build`.

The module supplies a precompiled Go object under a `.syso` filename. `cmd/go`
packs it without inspecting its serialized cgo directives. `cmd/link` then
reads the embedded `cgo_ldflag` values and forwards them to the host compiler
driver without applying the source-level linker-flag checks. A second native
object forces external linking even when `CGO_ENABLED=0` and the dependency
does not import `C`.

I reproduced the issue with unmodified Go 1.26.10, Go 1.27.3, and Go tip at
`deab4989e6586057f154e164ab92940b79b8ed19`.

The Apple-silicon macOS demonstration is:

```sh
DEMO_ROOT="$(mktemp -d /tmp/go-syso-calculator.XXXXXX)"
gh repo clone benr00t3d/go-syso-build-rce-poc "$DEMO_ROOT/repo"
cd "$DEMO_ROOT/repo"
go build
```

Calculator opens while the host linker processes the crafted package. The
link then fails intentionally, and no target executable is produced or run.
The same result was verified on macOS 15 with Apple Clang 17 and macOS 27 with
Apple Clang 21. The source-level control containing the same flags is rejected
before Calculator opens.

The separate Linux reproduction uses an empty module cache and a local module
proxy. The Go toolchain downloads the crafted dependency and creates a local
marker during the build. I also reproduced it when the crafted module was only
an indirect dependency.

Materials:

- Repository: https://github.com/benr00t3d/go-syso-build-rce-poc
- Full report: https://github.com/benr00t3d/go-syso-build-rce-poc/blob/main/disclosure/REPORT.md
- Clean reproduction revision: `613ffce47bc3616e54844463bbf3f1edd25d84fc`
- macOS CI receipt revision: `17f0a5574a8b25ae465db3390992fb028071ed76`
- Candidate fix: https://github.com/benr00t3d/go-syso-build-rce-poc/blob/main/disclosure/FIX.patch
- Video: [private video URL]

The repository contains the minimal macOS visual test, the downloaded-module
test, deterministic carrier construction, matched controls, and hashes. The
candidate fix rejects Go compiler objects presented as `.syso` files and keeps
Go's existing native `.syso` test passing.

This appears to match the Go security decision that a malicious module causing
`go build` to execute arbitrary code belongs on the private track.

Preferred attribution: Robert Prast

Thank you,

Robert Prast
