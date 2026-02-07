---
name: review-pr
description: Use when performing comprehensive PR review - orchestrates specialized reviewers
---

# PR Review Orchestration

## Layered Review Process

### Pass 1: GridGain Domain Reviewers (Parallel)

1. **Fetch PR diff** - Get changed files
2. **Route to reviewers** based on file types:
   - `.java`, `.cs` → gg-safety-reviewer + gg-quality-reviewer + gg-testing-reviewer
   - `.cpp`, `.h`, `.cmake`, `.sh` → gg-cpp-reviewer
   - `build.gradle`, `CMakeLists.txt` → gg-build-reviewer
3. **Run reviewers in parallel**
4. **Aggregate results** by severity

### Pass 2: Architecture Review (Sequential)

5. **Dispatch code-reviewer** for plan alignment, architecture, design patterns

## Reviewer Dispatch

```
IF changed_files contain .java OR .cs:
    → gg-safety-reviewer, gg-quality-reviewer, gg-testing-reviewer

IF changed_files contain .cpp OR .h OR .cmake:
    → gg-cpp-reviewer

IF changed_files contain build.gradle OR CMakeLists.txt:
    → gg-build-reviewer

ALWAYS (after domain reviewers):
    → code-reviewer (plan alignment, architecture)
```

## Output Format

Sort findings:
1. CRITICAL - Must fix
2. HIGH - Should fix
3. MEDIUM - Recommended
4. LOW - Nice to have

Deduplicate across reviewers.

For complete rules, see `guidelines/CODE_REVIEW_AGENT_SPEC.md`
