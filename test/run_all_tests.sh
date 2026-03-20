#!/bin/sh
set -eu

API_BASE_URL="${API_BASE_URL:-http://web:5001/api}"

echo "=== Running integration tests ==="
pytest -q test/test_integration_flows.py

echo "=== Running API simulator tests ==="
python test/minitwit_simulator.py "${API_BASE_URL}"

echo "=== Running UI and E2E browser tests ==="
pytest -q test/test_itu_minitwit_ui.py

echo "=== All test suites passed ==="
