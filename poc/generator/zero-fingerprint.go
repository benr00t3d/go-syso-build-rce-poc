package main

import (
	"bytes"
	"encoding/hex"
	"fmt"
	"os"
)

var objectMagic = []byte("\x00go120ld")

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: zero-fingerprint INPUT OUTPUT")
		os.Exit(2)
	}

	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		panic(err)
	}
	magic := bytes.Index(data, objectMagic)
	if magic < 0 || bytes.Index(data[magic+len(objectMagic):], objectMagic) >= 0 {
		panic("expected exactly one Go object magic header")
	}
	fingerprint := magic + len(objectMagic)
	if fingerprint+8 > len(data) {
		panic("truncated Go object fingerprint")
	}
	if bytes.Equal(data[fingerprint:fingerprint+8], make([]byte, 8)) {
		panic("input fingerprint is already zero")
	}

	fmt.Printf("magic_offset=%d\n", magic)
	fmt.Printf("fingerprint_offset=%d\n", fingerprint)
	fmt.Printf("original_fingerprint=%s\n", hex.EncodeToString(data[fingerprint:fingerprint+8]))
	clear(data[fingerprint : fingerprint+8])
	if err := os.WriteFile(os.Args[2], data, 0o644); err != nil {
		panic(err)
	}
}
