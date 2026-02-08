# GGCoder Test Suite

Tests for the GGCoder plugin, covering both structural validation and behavioral testing.

## Quick Start

```bash
# Run structural tests only (fast, no Claude CLI needed)
./run-tests.sh

# Run all tests including behavioral (requires Claude CLI, slower)
./run-tests.sh --behavioral

# Verbose output
./run-tests.sh --verbose
```

## Test Categories

### Structural Tests (Always Run)

These tests verify plugin configuration without invoking Claude:

| Test | Description |
|------|-------------|
| `test-structural.sh` | Plugin structure, naming consistency, component configuration |
| `test-hook-output.sh` | Session hook JSON output, escaping, warning generation |

**What they check:**
- `using-ggcoder` skill exists and has correct frontmatter
- Old `using-superpowers` is removed
- Session hook outputs valid JSON with correct structure
- All 11 gg-* agents exist with proper configuration
- All 5 commands have required frontmatter
- All GridGain pattern skills exist
- Plugin manifest (plugin.json) is valid
- Marketplace manifest (marketplace.json) is valid
- Conflict detection for superpowers plugin
- Legacy directory detection

### Behavioral Tests (Optional)

These tests invoke Claude CLI to verify agent behavior:

| Test | Description |
|------|-------------|
| `test-reviewer-behavior.sh` | Reviewer agents detect issues in code samples |

**What they check:**
- Safety reviewer detects concurrency issues (HashMap thread safety)
- Safety reviewer detects resource leaks (unclosed streams)
- Safety reviewer detects null safety issues
- Reviewers don't raise false positives on clean code
- Layered review process is configured correctly

**Requirements:**
- Claude Code CLI installed (`claude --version`)
- Each behavioral test takes 30-120 seconds

## Test Methodology

### Structural Tests

Standard assertion-based testing:
- File existence checks
- JSON validation with `jq`
- Content pattern matching with `grep`
- Exit code verification

### Behavioral Tests

Based on the **writing-skills** TDD methodology for skills:

1. **Code Fixtures**: Known-bad code samples with specific issues
2. **Prompt Injection**: Feed code to reviewer agent prompts
3. **Output Validation**: Check if agent detected expected issues
4. **False Positive Check**: Verify clean code doesn't trigger warnings

The behavioral tests follow the RED-GREEN-REFACTOR cycle:
- **RED**: Code with issues should produce findings
- **GREEN**: Code without issues should not produce false positives

## Test Fixtures

Located in temp directory during test run:

| Fixture | Issues |
|---------|--------|
| `ConcurrencyIssue.java` | Non-thread-safe HashMap, check-then-act race |
| `ResourceLeak.java` | Unclosed FileInputStream |
| `NullIssue.java` | Missing null checks, potential NPE |
| `GoodCode.java` | Clean code (should have no issues) |

## Adding New Tests

### Structural Test

Add checks to `test-structural.sh`:

```bash
# Check something exists
if [ -f "$PLUGIN_ROOT/path/to/file" ]; then
    pass "File exists"
else
    fail "File missing" "Expected: path/to/file"
fi

# Check content
if grep -q "pattern" "$file"; then
    pass "Pattern found"
else
    fail "Pattern missing" "Expected: pattern"
fi
```

### Behavioral Test

Add to `test-reviewer-behavior.sh`:

```bash
# Create fixture
cat > "$FIXTURES_DIR/NewIssue.java" <<'EOF'
// Code with known issue
EOF

# Test detection
prompt="You are the gg-safety-reviewer agent. Review this code:
$(cat "$FIXTURES_DIR/NewIssue.java")
Report issues with confidence levels."

if output=$(timeout 120 claude -p "$prompt" --allowedTools "" 2>&1); then
    if echo "$output" | grep -qi "expected_pattern"; then
        pass "Detected expected issue"
    else
        fail "Missed expected issue" "Should detect X"
    fi
fi
```

## CI Integration

For CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run GGCoder Tests
  run: |
    cd tests/ggcoder
    ./run-tests.sh
    # Add --behavioral if Claude CLI is available in CI
```

## Troubleshooting

### "jq: command not found"

Install jq:
```bash
# macOS
brew install jq

# Ubuntu/Debian
apt-get install jq
```

### "Claude CLI not found"

Behavioral tests require Claude Code CLI. Install from https://claude.ai/code

Structural tests will still run without it.

### Hook test fails with "invalid JSON"

Check `hooks/session-start.sh` for:
- Syntax errors in bash
- Unescaped characters in output
- Missing escape_for_json on content with special characters
