#!/bin/bash
# Revolutionary Technology - XDP Compiler
# Compiles xdp_echo.c into an eBPF object file

BPF_DIR="/usr/local/csf/bpf"
SOURCE="$BPF_DIR/xdp_echo.c"
OUTPUT="$BPF_DIR/xdp_echo.o"

if [ ! -f "$SOURCE" ]; then
    echo "Error: Source file $SOURCE not found."
    exit 1
fi

echo "Compiling $SOURCE to $OUTPUT..."

# Compile using clang
# -O2 is required for BPF
# -target bpf tells LLVM to generate BPF bytecode
clang -O2 -g -Wall -target bpf -c "$SOURCE" -o "$OUTPUT"

if [ $? -eq 0 ]; then
    echo "Compilation successful: $OUTPUT"
else
    echo "Compilation failed."
    exit 1
fi