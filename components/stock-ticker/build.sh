#!/bin/bash
set -euo pipefail

NAME="stock-ticker"
WORLD="stock-ticker"
WIT_DIR="./wit"
COMPONENT="${NAME}.wasm"
OUTPUT="../${NAME}.wasm"

echo "Building ${NAME} component with TinyGo (WASI preview 2 target + embedded WIT)..."
tinygo build \
  -target wasip2 \
  -opt=2 \
  --wit-package "${WIT_DIR}" \
  --wit-world "${WORLD}" \
  -o "${COMPONENT}" \
  main.go

echo "Copying component to ${OUTPUT}..."
cp "${COMPONENT}" "${OUTPUT}"

echo "Validating component..."
wasm-tools validate "${OUTPUT}"

echo "Extracting WIT to verify exports..."
wasm-tools component wit "${OUTPUT}" >/dev/null && echo "  - WIT export OK"

echo ""
echo "✓ Build complete!"
ls -lh "${OUTPUT}"
