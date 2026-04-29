#!/bin/bash
set -e

NAME="csv-groupby"
TARGET="wasm32-wasip2"

echo "Building $NAME component (WASI preview 2)..."
cargo component build --release --target $TARGET

echo "Copying to components/bin/$NAME.wasm..."
mkdir -p ../bin
cp target/$TARGET/release/${NAME//-/_}.wasm ../bin/$NAME.wasm

echo "Validating..."
wasm-tools validate ../bin/$NAME.wasm

echo ""
echo "✓ Build complete!"
ls -lh ../bin/$NAME.wasm
echo ""
echo "Exported interfaces:"
wasm-tools component wit ../bin/$NAME.wasm | grep -E "(export|execute-group-by)" | head -5