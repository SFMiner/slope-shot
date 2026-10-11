#!/bin/bash
# Run every headless test suite (tests/**/test_*.gd) under the project's autoloads.
# Usage: ./tests/run_all_tests.sh
# Set GODOT to the Godot 4.5 binary if it is not `godot` on PATH, e.g.
#   GODOT=../Godot_v4.5-stable_win64.exe ./tests/run_all_tests.sh

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 1

if ! command -v "$GODOT" &> /dev/null; then
	echo "ERROR: Godot not found ($GODOT). Set GODOT to the Godot 4.5 binary."
	exit 1
fi

echo "Running Slope Shot Tests"
echo "=========================="

PASSED=0
FAILED=0
FAILED_NAMES=()

for suite in $(find tests -name 'test_*.gd' | sort); do
	echo ""
	echo "--- $suite"
	timeout 120 "$GODOT" --headless --path . --script "$suite"
	if [ $? -eq 0 ]; then
		((PASSED++))
	else
		((FAILED++))
		FAILED_NAMES+=("$suite")
	fi
done

echo ""
echo "=========================="
echo "Overall Results: $PASSED suites passed, $FAILED failed"
for name in "${FAILED_NAMES[@]}"; do
	echo "  FAILED: $name"
done
echo "=========================="

[ "$FAILED" -eq 0 ]
