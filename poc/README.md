# Minimal reproduction

This reproduction uses a local file module proxy. It does not contact a third
party and the target program is never run. The only host-side effect is a
temporary marker at `/tmp/go-syso-module-marker`, which `verify.sh` removes on
exit.

Requirements:

- Linux amd64
- an affected Go toolchain (verified with Go 1.27.3)
- GCC on `PATH`

Run:

```sh
./verify.sh /path/to/affected/go
```

Expected result:

```text
build_status=1
host_marker=yes
module_downloaded=yes
```

The failed target link is expected. The security result is that the marker is
created by the host linker before any target executable exists or runs. Set
`KEEP_TMP=1` to retain the build transcript.

`generator/` reconstructs `directive.syso` from an ordinary Go compiler
object and documents the single eight-byte transformation.
