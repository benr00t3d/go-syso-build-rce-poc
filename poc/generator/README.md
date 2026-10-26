# Rebuilding the directive carrier

This directory shows that `directive.syso` is not an opaque handcrafted
object. Go 1.27.3 compiles `_cgo_payload.go` into a normal package archive.
`generate.sh` extracts its `_go_.o` member and zeros the eight-byte package
fingerprint immediately after the documented Go object magic header.

Run:

```sh
./generate.sh /path/to/go1.27.3/bin/go
```

For the official Linux amd64 Go 1.27.3 toolchain, the expected hashes are:

```text
e8df2f8410cbf4667c525172d439415b0285f89d1cc8b2ac5d81c7dd4b6eb067  payload.a
14daca8f6a908706a22454141963136e279ab817c099f796ec4a05f8211e6a38  _go_.o
d8440e34b71bd3d5058dc5ea7c76f1509efc1c18049e7c54a1d0fcc7fb2377f5  directive.syso
```

The generated `directive.syso` is byte-identical to the file in the module
zip. Exactly eight bytes differ from the compiler output.
