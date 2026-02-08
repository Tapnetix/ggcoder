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

| Test | Description | Duration |
|------|-------------|----------|
| `test-reviewer-behavior.sh` | Reviewer agents detect issues in code samples | ~2-5 min |
| `test-skill-triggering.sh` | Skills get triggered from natural prompts | ~5-10 min |
| `test-skill-utilization.sh` | Skills are FOLLOWED, not just loaded | ~10-15 min |

**What they check:**

**Reviewer Behavior:**
- Safety reviewer detects concurrency issues (HashMap thread safety)
- Safety reviewer detects resource leaks (unclosed streams)
- Safety reviewer detects null safety issues
- Reviewers don't raise false positives on clean code

**Skill Triggering:**
- `brainstorming` triggers on feature requests
- `test-driven-development` triggers on implementation requests
- `systematic-debugging` triggers on bug reports
- `concurrency-patterns` triggers on thread safety questions
- `review-pr` triggers on PR review requests

**Skill Utilization (the key tests):**
- TDD skill causes **test-first behavior** (not just mentioning TDD)
- Debugging skill causes **systematic process** (hypothesis, evidence, root cause)
- Concurrency patterns provides **GridGain-specific guidance**
- /review uses **layered process** (domain reviewers then architecture)

**Requirements:**
- Claude Code CLI installed (`claude --version`)
- Full behavioral suite takes 20-30 minutes

## Test Methodology

### Structural Tests

Standard assertion-based testing:
- File existence checks
- JSON validation with `jq`
- Content pattern matching with `grep`
- Exit code verification

### Behavioral Tests

Based on the **writing-skills** TDD methodology for skills.

#### Key Insight: Triggering ≠ Utilization

Loading a skill is **necessary but not sufficient**. We must verify:

1. **Skill Triggering**: The Skill tool is invoked for the right skill
2. **Skill Utilization**: Agent behavior actually changes to match skill content

Example: TDD skill should not just be loaded - it should cause the agent to:
- Write tests **before** implementation code
- Mention watching tests fail
- Follow RED-GREEN-REFACTOR cycle

The `test-skill-utilization.sh` tests look for **behavioral indicators** that prove the skill was followed, not just read.

#### Test Types

**1. Code Fixtures** (test-reviewer-behavior.sh)
- Known-bad code samples with specific issues
- Feed to reviewer agent prompts
- Verify issues are detected
- Verify clean code doesn't trigger false positives

**2. Skill Triggering** (test-skill-triggering.sh)
- Natural prompts that should trigger specific skills
- Verify Skill tool is invoked with correct skill name
- Check that skill wasn't loaded AFTER taking action

**3. Skill Utilization** (test-skill-utilization.sh)
- Pressure scenarios that tempt violation
- Check for behavioral indicators (not just keywords)
- Example: Did agent write test file BEFORE implementation?
- Example: Did agent form hypothesis BEFORE proposing fix?

The tests follow RED-GREEN-REFACTOR:
- **RED**: Without skill, agent takes wrong approach
- **GREEN**: With skill, agent follows correct process

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
