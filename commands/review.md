---
name: review
description: Run comprehensive code review using specialized reviewers
arguments:
  - name: target
    description: PR number, branch, or file paths
    required: false
---

# GGCoder Review

Run layered review using specialized agents.

## Usage

```
/review               # Review current branch
/review 1234          # Review PR #1234
/review feature-x     # Review branch
```

## Layered Review Process

### Pass 1: GridGain Domain Reviewers (Parallel)

Dispatches in parallel based on file types:

1. **gg-safety-reviewer** - Critical/High: concurrency, resources, null safety, type safety
2. **gg-quality-reviewer** - Medium/Low: dead code, duplication, logging, style
3. **gg-testing-reviewer** - Test quality: coverage, assertions, flakiness
4. **gg-cpp-reviewer** - If .cpp/.h/.cmake/.sh files: headers, ownership, scripts
5. **gg-build-reviewer** - If build files: dependencies, API consistency

### Pass 2: Architecture Review (Sequential)

After domain issues are addressed:

6. **code-reviewer** - Plan alignment, architecture, design patterns, documentation

## Results

Aggregated and sorted by severity: CRITICAL → HIGH → MEDIUM → LOW

Deduplicated across reviewers.

## After Review

Fix issues with specialized fixers:
```
/fix safety    # gg-safety-fixer
/fix quality   # gg-quality-fixer
/fix tests     # gg-test-fixer
/fix docs      # gg-doc-fixer
/fix cpp       # gg-cpp-fixer
/fix build     # gg-build-fixer
```
