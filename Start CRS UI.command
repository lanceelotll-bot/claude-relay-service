#!/bin/bash
set -euo pipefail

cd "/Users/wamg/Documents/test3/CRS-local"
bash scripts/dev-ui-start.sh

echo
echo "Frontend dev UI ready."
echo "Open: http://127.0.0.1:3001/admin/"
echo
read -r -p "Press Enter to close..."
