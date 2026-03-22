# Code Quality Reviewer Prompt Template

Use this template when dispatching code quality reviewer subagents.

**Purpose:** Verify implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.**

## Layered Review Process

### Pass 1: GridGain Domain Reviewers (Parallel)

Dispatch based on changed file types:

```
For .java/.cs files → dispatch in parallel:
  - ggcoder:gg-safety-reviewer (concurrency, resources, null safety)
  - ggcoder:gg-quality-reviewer (dead code, duplication, style)
  - ggcoder:gg-testing-reviewer (if test files changed)

For .cpp/.h/.cmake/.sh files:
  - ggcoder:gg-cpp-reviewer

For build.gradle/CMakeLists.txt:
  - ggcoder:gg-build-reviewer
```

### Pass 2: Architecture Review (Sequential)

After domain issues addressed:

```
Task tool (ggcoder:code-reviewer):
  Use template at requesting-code-review/code-reviewer.md

  WHAT_WAS_IMPLEMENTED: [from implementer's report]
  PLAN_OR_REQUIREMENTS: Task N from [plan-file]
  BASE_SHA: [commit before task]
  HEAD_SHA: [current commit]
  DESCRIPTION: [task summary]
```

**In addition to standard code quality concerns, the reviewer should check:**
- Does each file have one clear responsibility with a well-defined interface?
- Are units decomposed so they can be understood and tested independently?
- Is the implementation following the file structure from the plan?
- Did this implementation create new files that are already large, or significantly grow existing files? (Don't flag pre-existing file sizes — focus on what this change contributed.)

**Code reviewer returns:** Strengths, Issues (Critical/Important/Minor), Assessment

## Quick Reference

| File Type | Reviewers |
|-----------|-----------|
| .java, .cs | gg-safety, gg-quality, gg-testing, then code-reviewer |
| .cpp, .h | gg-cpp, then code-reviewer |
| build.gradle | gg-build, then code-reviewer |
| Other | code-reviewer only |
