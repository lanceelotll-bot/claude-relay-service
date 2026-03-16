#!/bin/bash
set -euo pipefail

cd "/Users/wamg/Documents/test3/CRS-local"
bash scripts/dev-start.sh

echo
echo "Backend ready."
echo "Health: http://127.0.0.1:3000/health"
echo
read -r -p "Press Enter to close..."
