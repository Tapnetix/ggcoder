#!/usr/bin/env bash
# Tests for session-start.sh hook output in various scenarios
# Tests JSON escaping, warning generation, and context injection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_SCRIPT="$PLUGIN_ROOT/hooks/session-start.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

passed=0
failed=0

pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    passed=$((passed + 1))
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    echo "        $2"
    failed=$((failed + 1))
}

info() {
    echo -e "${YELLOW}$1${NC}"
}

echo "========================================"
echo " GGCoder Hook Output Tests"
echo "========================================"
echo ""

# ============================================
# Test 1: Basic Hook Execution
# ============================================
info "1. Basic Hook Execution"

# Run hook and capture output
hook_output=$("$HOOK_SCRIPT" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    pass "Hook exits with code 0"
else
    fail "Hook exits with non-zero code" "Exit code: $exit_code"
fi

# ============================================
# Test 2: JSON Structure Validation
# ============================================
info "2. JSON Structure Validation"

# Validate JSON
if echo "$hook_output" | jq . >/dev/null 2>&1; then
    pass "Output is valid JSON"
else
    fail "Output is not valid JSON" "Parse error"
    echo "Raw output (first 500 chars):"
    echo "${hook_output:0:500}"
    exit 1
fi

# Check structure
if echo "$hook_output" | jq -e '.hookSpecificOutput' >/dev/null 2>&1; then
    pass "Has .hookSpecificOutput key"
else
    fail "Missing .hookSpecificOutput" "Required root key"
fi

if echo "$hook_output" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1; then
    pass "hookEventName is 'SessionStart'"
else
    fail "hookEventName incorrect" "Expected: SessionStart"
fi

# ============================================
# Test 3: Context Content Validation
# ============================================
info "3. Context Content Validation"

context=$(echo "$hook_output" | jq -r '.hookSpecificOutput.additionalContext')

# Check EXTREMELY_IMPORTANT wrapper
if echo "$context" | grep -q "EXTREMELY_IMPORTANT"; then
    pass "Context has EXTREMELY_IMPORTANT wrapper"
else
    fail "Missing EXTREMELY_IMPORTANT wrapper" "Required for priority"
fi

# Check ggcoder branding
if echo "$context" | grep -q "ggcoder powers"; then
    pass "Context says 'ggcoder powers'"
else
    fail "Missing 'ggcoder powers'" "Should announce ggcoder"
fi

# Check skill reference format
if echo "$context" | grep -q "ggcoder:using-ggcoder"; then
    pass "Context references 'ggcoder:using-ggcoder' skill"
else
    fail "Missing skill reference" "Should reference ggcoder:using-ggcoder"
fi

# Check skill content is embedded
if echo "$context" | grep -q "How to Access Skills"; then
    pass "using-ggcoder skill content is embedded"
else
    fail "Skill content not embedded" "Should contain skill content"
fi

# ============================================
# Test 4: JSON Escaping
# ============================================
info "4. JSON Escaping"

# The embedded skill content has quotes, newlines, etc. that need escaping
# If we got here, basic escaping works. Test for specific patterns.

# Check that escaped newlines are present in raw JSON
raw_json="$hook_output"
if echo "$raw_json" | grep -q '\\n'; then
    pass "Newlines are properly escaped"
else
    # Might be using actual newlines in JSON (also valid)
    if echo "$raw_json" | jq -r '.hookSpecificOutput.additionalContext' | grep -q $'\n'; then
        pass "Context contains newlines (parsed correctly)"
    else
        fail "Newline handling issue" "Check escape_for_json function"
    fi
fi

# Check that quotes in skill content don't break JSON
skill_has_quotes=$(echo "$context" | grep -c '"' || echo "0")
if [ "$skill_has_quotes" -gt 0 ]; then
    pass "Embedded quotes handled correctly (found $skill_has_quotes)"
else
    fail "No quotes found in context" "Skill content should have quotes"
fi

# ============================================
# Test 5: Legacy Warning Generation
# ============================================
info "5. Legacy Warning Simulation"

# Create temporary legacy directory
legacy_dir="$HOME/.config/superpowers/skills"
cleanup_legacy=false

if [ ! -d "$legacy_dir" ]; then
    mkdir -p "$legacy_dir"
    cleanup_legacy=true
    echo "  (Created temporary legacy directory for testing)"
fi

# Run hook again
legacy_output=$("$HOOK_SCRIPT" 2>&1)

# Check for warning
if echo "$legacy_output" | jq -r '.hookSpecificOutput.additionalContext' | grep -qi "WARNING.*Legacy"; then
    pass "Legacy directory warning generated"
else
    # Check if warning is in the output
    if echo "$legacy_output" | grep -qi "legacy"; then
        pass "Legacy directory detected (warning in output)"
    else
        fail "Legacy directory not detected" "Should warn about ~/.config/superpowers/skills"
    fi
fi

# Cleanup
if [ "$cleanup_legacy" = true ]; then
    rmdir "$legacy_dir" 2>/dev/null || true
    rmdir "$HOME/.config/superpowers" 2>/dev/null || true
    echo "  (Cleaned up temporary legacy directory)"
fi

echo ""

# ============================================
# Test 6: Performance Check
# ============================================
info "6. Performance Check"

# Hook should complete quickly (< 2 seconds)
start_time=$(date +%s%N)
"$HOOK_SCRIPT" >/dev/null 2>&1
end_time=$(date +%s%N)

# Calculate duration in milliseconds
duration_ms=$(( (end_time - start_time) / 1000000 ))

if [ "$duration_ms" -lt 2000 ]; then
    pass "Hook completes in ${duration_ms}ms (< 2s)"
else
    fail "Hook too slow" "Took ${duration_ms}ms, should be < 2000ms"
fi

echo ""

# ============================================
# Summary
# ============================================
echo "========================================"
echo " Test Results Summary"
echo "========================================"
echo ""
echo -e "  ${GREEN}Passed:${NC}  $passed"
echo -e "  ${RED}Failed:${NC}  $failed"
echo ""

if [ $failed -gt 0 ]; then
    echo -e "${RED}STATUS: FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}STATUS: PASSED${NC}"
    exit 0
fi
