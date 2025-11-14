#!/bin/bash
set -e

NAME="csv-groupby"
TARGET="wasm32-wasip2"

echo "Building $NAME component (WASI preview 2)..."
cargo component build --release --target $TARGET

echo "Copying to components/$NAME.wasm..."
cp target/$TARGET/release/${NAME//-/_}.wasm ../$NAME.wasm

echo "Validating..."
wasm-tools validate ../$NAME.wasm

echo ""
echo "✓ Build complete!"
ls -lh ../$NAME.wasm
echo ""
echo "Exported interfaces:"
wasm-tools component wit ../$NAME.wasm | grep -E "(export|execute-group-by)" | head -5