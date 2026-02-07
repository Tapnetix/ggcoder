# Code Review Guidelines for GridGain 9 / Apache Ignite 3

This document provides guidelines for automated code review agents based on patterns observed in actual PR reviews from both the ggprivate/gridgain-9 and apache/ignite-3 repositories.

## Overview

These guidelines are derived from analysis of **~120 pull requests with 500+ review comments** spanning **9 months** (May 2025 - Feb 2026) from both repositories:
- **GridGain 9** (ggprivate/gridgain-9): PRs #2234-#3625 (May 2025 - Feb 2026)
- **Apache Ignite 3** (apache/ignite-3): PRs #6322-#7530 (July 2025 - Feb 2026)

The goal is to enable consistent, thorough code reviews that catch common issues before they reach production.

---

## 1. Concurrency and Thread Safety

**Priority: Critical**

### What to Check

1. **Race Conditions in Shared State**
   - Arrays/collections accessed from multiple threads without synchronization
   - Non-atomic read-modify-write sequences
   - State checks followed by state modifications without holding locks

2. **Visibility Issues**
   - Fields accessed from multiple threads should be `volatile` or protected by synchronization
   - Ensure happens-before relationships exist between writes and reads

3. **Lock Ordering**
   - Operations on shared data should be inside critical sections
   - Check if locking defeats the purpose of concurrent design

### Example Comments

```
"The timestamp ordering check and update of last_inserted occur before acquiring
the modification_mutex lock. This creates a race condition where multiple threads
could read the same value. These operations should be moved inside the critical
section after acquiring the lock."

"The `synchronized` keyword on handleCqRes serializes all partition response
processing, which defeats the purpose of the 'independent partition polling'
optimization. Consider using finer-grained locking or thread-local resources."

"The statuses array is accessed without synchronization at line 220, but is
written within the synchronized handleCqRes method. This creates a race condition.
Consider marking the field as `volatile` or ensuring all accesses are synchronized."
```

---

## 2. Resource Management

**Priority: Critical**

### What to Check

1. **Memory Leaks**
   - Buffers not released after use
   - Resources held after close() is called
   - Large objects retained unnecessarily

2. **Idempotent Close Operations**
   - `close()` methods must be safe to call multiple times
   - Check for NPE when closing partially-initialized resources
   - Ensure cleanup in finally blocks

3. **Context Restoration**
   - Thread context classloaders must be restored in finally blocks
   - Any temporarily modified state should be restored

### Example Comments

```
"Please release the buffer in `channelRead` instead, this looks like a genuine leak."

"close() is no longer idempotent: after hasNext() reaches the end it calls close()
and sets nativeCursor = null, so any subsequent close() will throw NPE. Make close()
null-safe and consider clearing lastRows to release the last page promptly."

"start() changes the thread context class loader but only restores it at the very
end, so any exception will leave the context class loader in an inconsistent state.
Wrap the body in try/finally."

"stop() unconditionally calls server.shutdown(), but server may be null if start()
failed before the server was constructed. Consider guarding with a null check."
```

---

## 3. Documentation Quality

**Priority: Medium**

### What to Check

1. **Typos and Grammar**
   - Common: "the the" → "the", "Commiting" → "Committing", "constains" → "contains"
   - Check for duplicate words
   - Verify correct capitalization (e.g., "GridGain" not "Gridgain")

2. **Incorrect References**
   - Javadoc @link references pointing to wrong classes
   - Comments describing wrong behavior
   - Outdated TODO references

3. **Clarity**
   - Ambiguous method/parameter descriptions
   - Comments that contradict the code
   - Missing context for complex logic

### Example Comments

```
"The JavaDoc references the wrong class. It should reference {@link VersionFormatException}
instead of {@link UpgradeStartExceptionHandler}."

"The comment says 'Manager can modify insert/delete row' which is grammatically
unclear. It should be 'Manager can insert/delete any row'."

"The documentation for finishFst is incorrect. It says 'Marks partition for Full
State Transfer' but should say 'Marks the end of Full State Transfer'."

"The Javadoc contains typos: `constains` should be `contains` and `lodaded` should
be `loaded`."
```

---

## 4. Code Quality

**Priority: Medium**

### What to Check

1. **Dead/Unused Code**
   - Methods defined but never called
   - Unused imports
   - Unreachable branches

2. **Redundant Logic**
   - Duplicate condition checks
   - Unnecessary null checks when already validated
   - Code that can be simplified

3. **Debug Artifacts**
   - Console output (System.out, print statements) in production code
   - Commented-out code blocks
   - Debug flags left enabled

### Example Comments

```
"The findCause method is defined but never used in the code. Consider removing
this unused helper method."

"This debug output should be removed before merging. Console output in tests can
clutter the test results and should only be used for temporary debugging."

"The else branch is unreachable because the validation logic always returns true
or throws an exception. Consider removing the else branch."

"The condition `isValidContext(securityContext) && safeToIncludeUserDetails()` is
redundant here. Simply check `if (userDetailsMessage != null)` instead."
```

---

## 5. Error Handling

**Priority: High**

### What to Check

1. **Null Safety**
   - Parameters should be validated with `Objects.requireNonNull()`
   - Nullable fields should have null checks before use
   - Return values from external APIs should be checked

2. **Exception Safety**
   - Resources cleaned up even when exceptions occur
   - Exceptions not silently swallowed without logging
   - Appropriate exception types used

3. **Error Messages**
   - Messages should be clear and actionable
   - Include relevant context (values, state)
   - Consistent formatting

### Example Comments

```
"The value parameter should be validated for null like the key parameter. Consider
adding Objects.requireNonNull(value, \"value is null\")."

"Or maybe even: `stream << \"upsert error - invalid timestamp [last_inserted: \"
<< last_inserted << \", tx_timestamp: \" << timestamp << \"]\";`"

"Let's put `table.securityEnabled()` check before map comparison."
```

---

## 6. API Design and Consistency

**Priority: Medium**

### What to Check

1. **Method Naming**
   - Should follow language idioms (e.g., `set` vs `put` in Python)
   - Symmetric operations should have symmetric names (`get_and_set`)
   - Names should accurately describe behavior

2. **Parameter Design**
   - Prefer simple parameters over complex callbacks when possible
   - Consider `onRead(boolean hit, boolean readOnly)` vs separate methods

3. **Type Safety**
   - Nullability annotations should match actual usage
   - Generic parameters should be meaningful

### Example Comments

```
"This method should probably be called `set` now, to be idiomatic in Python."

"Let's rename to `get_and_set` for symmetry."

"The nullability annotation on lastRows changed from 'nullable array' to 'array
with nullable elements'. Consider reverting to match actual usage/contract."

"Perhaps it would be better to add a new parameter to the onRead method as follows:
void onRead(boolean hit, boolean readOnly). It allows us to simplify the code."
```

---

## 7. Testing

**Priority: High**

### What to Check

1. **Coverage Gaps**
   - Test only validates one scenario when multiple exist
   - Async/sync variants not both tested
   - Edge cases not covered

2. **Test Data**
   - Using only one key/record when testing distributed systems
   - Not testing with realistic data volumes

3. **Test Assertions**
   - Weak assertions that don't verify behavior
   - Missing negative test cases

### Example Comments

```
"The test only validates key type mismatch. Consider adding a test case that
validates value type mismatch as well."

"The test only validates the synchronous destroy method. Consider adding test
coverage for the async version."

"You are using 2 nodes for a reason, possibly to test the distributed component.
But you are using only one key in most tests, I think we need more data."

"Can you rewrite this using improved matchers, something like assertThrowsProblem(...)?"
```

---

## 8. Code Style and Organization

**Priority: Low**

### What to Check

1. **Indentation Consistency**
   - Mixed tabs/spaces
   - Inconsistent nesting levels

2. **Constants Extraction**
   - Magic numbers/strings should be constants
   - Repeated values should be extracted

3. **Code Structure**
   - Complex logic should be extracted to methods
   - Related code should be grouped together

### Example Comments

```
"Inconsistent indentation: this line uses an extra space (13 spaces instead of 12)."

"Let's extract this to constant: private static final String VERSION_TO_UPGRADE = \"9.9.9\";"

"Definitely should be a method."

"Can we drastically simplify this?"

"The canonical way is to define a private final variable in the holder class,
and initialize it in the constructor instead of a local variable."
```

---

## 9. Build and Dependencies

**Priority: Medium**

### What to Check

1. **Version Management**
   - BOM-managed dependencies shouldn't have explicit versions
   - Version references should be consistent

2. **License Compliance**
   - New dependencies should have compatible licenses
   - License information should be preserved in packages

3. **Module Documentation**
   - New modules should have README files explaining purpose

### Example Comments

```
"I'm wondering if it's ok to omit version.ref for this dependency. There is
another example of adding bom to the project where version is provided."

"The removal of license information from package metadata may be problematic.
NuGet packages typically require license information."

"Let's add a few lines describing why do we need this module."
```

---

## 10. Upstream Considerations

**Priority: Medium**

### What to Check

1. **Apache Ignite Coordination**
   - Changes that should go to Ignite first
   - Fixes that need to be coordinated with upstream

2. **Ticket References**
   - TODOs should reference proper ticket numbers
   - Commit messages should include ticket IDs

### Example Comments

```
"Shouldn't it be done in Ignite first?"

"Added todo in Ignite ticket."

"TODO: IGNITE-27632 Use a default field value instead of nullable."
```

---

## Review Comment Format

When writing review comments, follow these patterns:

### For Suggestions with Code

```markdown
[Brief description of the issue]
```suggestion
[corrected code]
```
```

### For Questions/Clarifications

```markdown
What is the value of response time here?

Why this is in the static initializer? Can't we use some lifecycle method for this?

Do we need this comment?
```

### For Detailed Explanations

```markdown
[Description of the problem]

[Explanation of why it's a problem]

[Suggested fix or approach]
```

---

## Severity Levels

Use these to prioritize review feedback:

| Level | When to Use | Examples |
|-------|------------|----------|
| **Critical** | Must fix before merge | Race conditions, memory leaks, security issues |
| **High** | Should fix before merge | Missing null checks, test coverage gaps, incorrect behavior |
| **Medium** | Fix recommended | Documentation issues, code clarity, API consistency |
| **Low/Nitpick** | Nice to have | Style issues, minor refactoring suggestions |

---

## Files to Focus On

Pay extra attention to:

1. **Production code** in `src/main/java` (vs test code)
2. **Concurrent/async code** - `Executor`, `Future`, `CompletableFuture`, synchronized blocks
3. **Resource handling** - `AutoCloseable`, `try-with-resources`, cleanup methods
4. **Public APIs** - interfaces, public methods, REST endpoints
5. **Integration points** - network, storage, external services

---

## What NOT to Flag

Avoid false positives on:

1. Test utilities and fixtures (unless they have actual bugs)
2. Generated code
3. Vendored third-party code
4. Style issues already handled by checkstyle/spotbugs
5. Minor preferences that don't affect correctness

---

## 11. C++ and CMake Specific (from Apache Ignite 3)

**Priority: High for C++ code**

### What to Check

1. **Header Self-Containment**
   - Headers should include all necessary standard headers (`<vector>`, `<cstddef>`, etc.)
   - Don't rely on transitive/indirect includes
   - Platform-specific headers (`<sys/socket.h>` on POSIX, `<winsock2.h>` on Windows)

2. **Ownership Semantics**
   - Resource-owning classes should be move-only (delete copy constructor/assignment)
   - Socket wrappers, file handles, etc. should not be copyable
   - Prevent double-close or use-after-close bugs

3. **CMake Configuration**
   - Install paths should be relative to install prefix, not build directory
   - Version compatibility should use `SameMajorVersion`, not `ExactVersion`
   - Component descriptions should be consistent across the project

4. **Platform-Specific Code**
   - Winsock initialization/cleanup must be balanced
   - Shell scripts need shebang lines (`#!/bin/bash`)
   - Error handling in scripts (`|| true` for best-effort cleanup)

### Example Comments

```
"The header uses std::vector but doesn't include <vector>. To make this header
self-contained, please add the necessary standard headers."

"server_socket_adapter is an owning wrapper around a socket handle but is copyable.
This can lead to double-closing. Consider deleting copy constructor/assignment and
adding move semantics."

"The version compatibility is set to ExactVersion, which is restrictive.
SameMajorVersion would be more appropriate for a library."

"The shell script is missing a shebang line. Without it, the script may not
execute correctly when called by package managers."

"WSAStartup is guarded by a static flag, but WSACleanup() is called unconditionally
for every instance. This leads to undefined behavior after the first cleanup."
```

---

## 12. Cross-Language Type Safety (from Apache Ignite 3)

**Priority: High**

### What to Check

1. **Integer Type Conversions**
   - `long` to `int` conversions need overflow checking
   - Use `Math.toIntExact()` or explicit range validation
   - Array indices from `long` partition IDs need safe casting

2. **Floating Point Comparisons**
   - Direct `==` comparison can be problematic
   - Consider NaN and infinity cases
   - Document intentional equality checks

3. **Cross-Platform API Differences**
   - Windows `recv()` takes `int` length, not `size_t`
   - Explicit casting with validation for API boundaries

### Example Comments

```
"hashPartition.Id is a long, but nodes is indexed by int. Use checked((int)hashPartition.Id)
to safely convert with overflow checking."

"CollectionAssert.AreEqual will fail because boxed int and boxed long are not equal.
Convert the expected sequence to long."

"The implicit narrowing from size_t to int can overflow for large buffers. Validate
that buf_size fits into an int or use an int parameter type."

"There is Math.toIntExact which might be simpler and faster."
```

---

## 13. Performance and Simplification (from Apache Ignite 3)

**Priority: Medium**

### What to Check

1. **Fast Paths**
   - Add early returns for common cases
   - Check most likely conditions first

2. **Simplification Opportunities**
   - Replace complex logic with standard library methods
   - Consolidate duplicate implementations into shared utilities

3. **Unnecessary Complexity**
   - Check if executor is actually needed (sync cache doesn't need async executor)
   - Remove redundant parameters or flags

### Example Comments

```
"Let's add a fast path for Byte to the very top of the method - likely the most
common case."

"The casting methods are duplicated across SqlRowImpl and TupleImpl with identical
implementations. Consider extracting into a shared utility class."

"We don't need any executor at all. It is just never used because we build
synchronous cache underneath. You can pass Runnable::run instead."

"Let's unify these methods?"

"I think that you don't need all that stuff at all. :)"
```

---

## 14. Logging and Error Reporting (from Apache Ignite 3)

**Priority: Medium**

### What to Check

1. **Log Level Consistency**
   - Logger level check should match actual logging level
   - `isWarnEnabled()` check with `warn()` call, not `isDebugEnabled()`

2. **Block-list vs Allow-list**
   - Error logging should use block-list (log by default, suppress specific)
   - Not allow-list (only log specific codes)

3. **Meaningful Keys**
   - Cache/throttle keys should be unique across dimensions
   - Avoid false collisions (e.g., connectionId=1+opCode=12 vs connectionId=11+opCode=2)

### Example Comments

```
"I would revert this part. Essentially it allows only codes from ERROR_CODES_TO_LOG
to be logged, which is not correct. Any unexpected exception should be logged.
We should have a block-list, not an allow-list."

"Should we change logger level check to WARN? Logging with WARN severity when only
debug is enabled is a bit misleading."

"Just to avoid false positive checks: connectionId=1, opCode=12 vs connectionId=11,
opCode=2. Use a delimiter: String.valueOf(connectionId) + ':' + String.valueOf(opCode)"
```

---

## 15. Test Quality Improvements (from Apache Ignite 3)

**Priority: Medium**

### What to Check

1. **Better Matchers**
   - Use `lessThanOrEqualTo` instead of manual comparisons
   - Use `assertThrowsProblem` with matchers for exception testing
   - Verify actual content, not just dimensions

2. **Test Logic**
   - Tests should not use disabled config and expect behavior
   - Hard-coded indices are fragile - prefer named accessors

3. **Documenting Test Purpose**
   - Add comments explaining why specific test setup is needed
   - Link to tickets for workarounds

### Example Comments

```
"These asserts could be better expressed using Matchers.lessThanOrEqualTo."

"Can we also test the result of the truncation, not only the total width?"

"You truncate with DISABLED config. It does not make sense."

"This hard-coded index to jump to node 'B' seems too fragile. There should be a
better way - perhaps adding a @TestOnly method."

"Please add a comment about why we do this (probably with a ticket link)."
```

---

## Interaction Guidelines

1. **Be specific** - Point to exact lines and provide concrete suggestions
2. **Explain why** - Don't just say "this is wrong", explain the consequence
3. **Be constructive** - Offer solutions, not just criticisms
4. **Acknowledge context** - Reviewers sometimes respond "That's intentional" - accept it gracefully
5. **Prioritize** - Focus on critical issues first, nitpicks last
6. **Ask clarifying questions** - "Why?" is a valid review comment when logic is unclear
7. **Explain technical nuances** - "This is a volatile read" helps others understand intent

---

## Additional Patterns from Extended Analysis

### Input Validation and Trimming

```
"Field names should be trimmed after splitting to handle whitespace around commas.
Users may write 'field1, field2' with spaces, which would result in ' field2' with
a leading space. Use Arrays.stream(str.split(",")).map(String::trim).collect(...)."
```

### Assertions vs Exceptions

```
"Replace assertion with proper null check and exception handling. Assertions can be
disabled at runtime and may not provide adequate error handling in production."
```

### Test Robustness

```
"This checks first node twice - bug in loop index."

"This condition is always false and this block can be removed."

"The reproducer in the ticket fails sometimes on main branch. The race condition is
difficult to test reliably. Any ideas?"
```

### Method Extraction

```
"Let's extract `unwrapIgniteImpl(cluster.node(i)).evictionManager().isEvictionRunning()`
to a method and reuse everywhere?"
```

### Hamcrest Matchers

```
"BTW, hamcrest is included by default in all tests so there's no need to depend on
it explicitly."

"Let's use Matchers.greaterThan here so that it will be clear from the error message
what the actual value was."
```

### Exception Messages

```
"All UnsupportedOperationException messages use generic 'This method should not be
called.' Consider making these messages more specific by including the method name
to aid debugging."
```

### Prefetch/Background Operations

```
"I would say that prefetch is more crucial for thin client rather than for embedded.
In case of embedded the next page is few layers of abstractions away, but for thin
client the whole page should be serialized, deserialized, and sent over the network."
```

### Micro-Optimizations

```
"Not sure but looks like lookup-by-index (e.g. for (int i = 0; i < searchRows.size()...))
was added intentionally. I'm not a fan of such micro-optimizations, but I think in
this case we either need to use the original 'style' or ask the author's opinion."
```

---

## Top Reviewers by Focus Area

| Reviewer | Repository | Focus Areas |
|----------|------------|-------------|
| **valepakh** | GG9 | Testing, CLI, matchers, constants |
| **sashapolo** | Both | Upstream coordination, general |
| **ptupitsyn** | Both | .NET, clients, performance |
| **ibessonov** | Both | Storage, page memory |
| **korlov42** | GG9 | SQL, performance, architecture |
| **sk0x50** | Both | Metrics, testing |
| **isapego** | Both | C++, platform code |
| **xtern** | GG9 | SQL, RLS, compatibility |
| **lowka** | Both | JDBC, client handler |
| **Copilot** | Both | Comprehensive automated checks |
