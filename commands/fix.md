---
name: fix
description: Fix issues identified by review using specialized fixers
arguments:
  - name: category
    description: Category to fix (safety, quality, tests, docs, cpp, build)
    required: true
---

# GGCoder Fix

Apply fixes for review findings.

## Usage

```
/fix safety    # gg-safety-fixer: concurrency, resources, null issues
/fix quality   # gg-quality-fixer: dead code, duplication
/fix tests     # gg-test-fixer: test coverage, assertions
/fix docs      # gg-doc-fixer: typos, Javadoc
/fix cpp       # gg-cpp-fixer: C++ headers, ownership
/fix build     # gg-build-fixer: dependencies, configs
```

## Fixer Agents

| Category | Agent | Skills Used |
|----------|-------|-------------|
| safety | gg-safety-fixer | concurrency-patterns, resource-cleanup-patterns, null-check-patterns |
| quality | gg-quality-fixer | performance-patterns |
| tests | gg-test-fixer | test-patterns |
| docs | gg-doc-fixer | - |
| cpp | gg-cpp-fixer | - |
| build | gg-build-fixer | version-compatibility-patterns |

## Workflow

Each fixer:
1. Reads review findings from the review output
2. Loads relevant skills for patterns
3. Applies TDD: write test → fix → verify
4. Commits when verified

For complete rules, see `guidelines/CODE_REVIEW_AGENT_SPEC.md`
