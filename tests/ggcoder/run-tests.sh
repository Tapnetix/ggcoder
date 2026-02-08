#!/usr/bin/env bash
# GGCoder Test Suite Runner
# Runs all ggcoder-specific tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo " GGCoder Test Suite"
echo "========================================"
echo ""
echo "Test directory: $SCRIPT_DIR"
echo "Date: $(date)"
echo ""

# Parse arguments
RUN_BEHAVIORAL=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --behavioral|-b)
            RUN_BEHAVIORAL=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --behavioral, -b   Run behavioral tests (requires Claude CLI, slow)"
            echo "  --verbose, -v      Show verbose output"
            echo "  --help, -h         Show this help"
            echo ""
            echo "Test Categories:"
            echo "  Structural Tests (always run):"
            echo "    - test-structural.sh     Plugin structure, naming, configuration"
            echo "    - test-hook-output.sh    Session hook JSON output validation"
            echo ""
            echo "  Behavioral Tests (use --behavioral):"
            echo "    - test-reviewer-behavior.sh  Reviewer agent issue detection"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Track results
total_passed=0
total_failed=0
total_skipped=0

run_test() {
    local test_name="$1"
    local test_file="$SCRIPT_DIR/$test_name"

    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Running: $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if [ ! -f "$test_file" ]; then
        echo -e "${YELLOW}[SKIP] Test file not found${NC}"
        total_skipped=$((total_skipped + 1))
        return
    fi

    chmod +x "$test_file"

    if [ "$VERBOSE" = true ]; then
        if bash "$test_file"; then
            echo -e "\n${GREEN}✓ $test_name PASSED${NC}"
        else
            echo -e "\n${RED}✗ $test_name FAILED${NC}"
            total_failed=$((total_failed + 1))
            return
        fi
    else
        if output=$(bash "$test_file" 2>&1); then
            echo -e "${GREEN}✓ $test_name PASSED${NC}"
        else
            echo -e "${RED}✗ $test_name FAILED${NC}"
            echo "$output" | tail -20
            total_failed=$((total_failed + 1))
            return
        fi
    fi

    total_passed=$((total_passed + 1))
}

# ============================================
# Run Structural Tests (always)
# ============================================
echo -e "${YELLOW}=== Structural Tests ===${NC}"

run_test "test-structural.sh"
run_test "test-hook-output.sh"

# ============================================
# Run Behavioral Tests (optional)
# ============================================
if [ "$RUN_BEHAVIORAL" = true ]; then
    echo -e "\n${YELLOW}=== Behavioral Tests ===${NC}"

    if ! command -v claude &> /dev/null; then
        echo -e "${YELLOW}WARNING: Claude CLI not found - behavioral tests will have limited coverage${NC}"
    fi

    run_test "test-reviewer-behavior.sh"
else
    echo -e "\n${YELLOW}Behavioral tests skipped (use --behavioral to run)${NC}"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "========================================"
echo " Final Results"
echo "========================================"
echo ""
echo -e "  ${GREEN}Passed:${NC}  $total_passed test files"
echo -e "  ${RED}Failed:${NC}  $total_failed test files"
echo -e "  ${YELLOW}Skipped:${NC} $total_skipped test files"
echo ""

if [ $total_failed -gt 0 ]; then
    echo -e "${RED}OVERALL STATUS: FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}OVERALL STATUS: PASSED${NC}"
    exit 0
fi
