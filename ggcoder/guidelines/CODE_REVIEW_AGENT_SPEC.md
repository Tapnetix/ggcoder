# Code Review Agent Specification for GridGain 9 / Apache Ignite 3

This document provides a technical specification for configuring an automated code review agent to review pull requests in the GridGain 9 and Apache Ignite 3 codebases.

---

## Agent Configuration

### Repository Context

**GridGain 9 (ggprivate/gridgain-9):**
- **Primary Language**: Java 11
- **Build System**: Gradle
- **Code Style**: Checkstyle (`check-rules/checkstyle-rules.xml`)
- **Static Analysis**: SpotBugs, PMD
- **Test Framework**: JUnit 5
- **Ticket Prefix**: GG-XXXXX

**Apache Ignite 3 (apache/ignite-3):**
- **Primary Language**: Java 11
- **Build System**: Gradle
- **Code Style**: Checkstyle (similar rules)
- **Static Analysis**: SpotBugs, PMD
- **Test Framework**: JUnit 5
- **Ticket Prefix**: IGNITE-XXXXX

### Review Scope

**Include:**
- `modules/*/src/main/java/**/*.java`
- `modules/*/src/integrationTest/java/**/*.java`
- `modules/*/src/test/java/**/*.java`
- `modules/platforms/cpp/**/*.cpp`
- `modules/platforms/cpp/**/*.h`
- `modules/platforms/cpp/**/*.cmake`
- `modules/platforms/cpp/cmake/**/*.cmake`
- `modules/platforms/python/**/*.py`
- `modules/platforms/dotnet/**/*.cs`
- `**/*.sh` (shell scripts)

**Exclude:**
- `**/build/**`
- `**/generated/**`
- `**/third-party/**`
- `**/*.md` (documentation only, unless grammar check requested)

---

## Review Rules

### Rule 1: Thread Safety Violations

**ID**: `THREAD_SAFETY_001`
**Severity**: Critical
**Pattern**: Detect unsynchronized access to shared mutable state

**Triggers:**
```java
// Field written in synchronized method, read outside
private SomeType[] sharedArray;

synchronized void writer() { sharedArray[i] = value; }
void reader() { return sharedArray[i]; }  // FLAG THIS

// Non-atomic check-then-act
if (map.containsKey(key)) {
    return map.get(key);  // FLAG: race between contains and get
}

// Concurrent access to non-thread-safe collections
private List<T> list = new ArrayList<>();  // FLAG if accessed from multiple threads
```

**Comment Template:**
```
The `{field}` field is accessed without synchronization at line {line}, but is
written within the synchronized `{method}` method at line {writeLine}. This
creates a race condition where one thread may read a stale or partially-written
value.

Consider:
- Marking the field as `volatile`
- Using a thread-safe collection (`ConcurrentHashMap`, etc.)
- Ensuring all accesses are within synchronized blocks
```

---

### Rule 2: Resource Leak Detection

**ID**: `RESOURCE_LEAK_001`
**Severity**: Critical
**Pattern**: Resources not properly released

**Triggers:**
```java
// Buffer not released
ByteBuf buf = ctx.alloc().buffer();
// ... no buf.release() before return/exception

// Non-idempotent close
public void close() {
    resource.close();  // FLAG if resource can be null after partial init
    resource = null;
}

// Missing finally for cleanup
ClassLoader old = Thread.currentThread().getContextClassLoader();
Thread.currentThread().setContextClassLoader(newLoader);
doSomething();  // FLAG: if exception, old classloader not restored
Thread.currentThread().setContextClassLoader(old);
```

**Comment Template:**
```
{resource} is allocated at line {allocLine} but may not be released if an
exception occurs before line {releaseLine}. Consider:
- Using try-with-resources
- Adding a finally block to ensure cleanup
- Making close() idempotent with null checks
```

---

### Rule 3: Incorrect Documentation

**ID**: `DOC_QUALITY_001`
**Severity**: Medium
**Pattern**: Javadoc/comments that don't match code

**Triggers:**
```java
/**
 * Handler for {@link WrongClass}  // FLAG: class reference doesn't match
 */
public class SomeExceptionHandler extends AbstractHandler<CorrectException> {}

// FLAG: Comment says one thing, code does another
/** Marks partition for Full State Transfer */  // But method is finishFst()
void finishFst() {}

// FLAG: Typos in documentation
/** This method constains the logic */  // constains -> contains
```

**Comment Template:**
```
The {docType} references `{referenced}` but should reference `{correct}`
based on the actual implementation.

OR

The {docType} contains a typo: `{typo}` should be `{correction}`.
```

---

### Rule 4: Dead Code Detection

**ID**: `DEAD_CODE_001`
**Severity**: Medium
**Pattern**: Unused methods, unreachable code, debug artifacts

**Triggers:**
```java
// FLAG: Private method never called
private void helperMethod() { ... }  // No callers in class

// FLAG: Unreachable branch
if (condition) {
    return true;
} else {
    throw new Exception();
}
return false;  // Unreachable

// FLAG: Debug output in non-test code
System.out.println("Debug: " + value);
Console.WriteLine("test");
```

**Comment Template:**
```
The `{method}` method is defined but never used in the code. Consider removing
this unused helper method.

OR

This debug output should be removed before merging. Console output in
production code can cause issues and should only be used temporarily.
```

---

### Rule 5: Null Safety

**ID**: `NULL_SAFETY_001`
**Severity**: High
**Pattern**: Missing null checks on parameters and return values

**Triggers:**
```java
// FLAG: Public method without parameter validation
public void process(String key, Object value) {
    map.put(key, value);  // key/value not checked for null
}

// FLAG: Nullable return used without check
SomeType result = possiblyNullMethod();
result.doSomething();  // NPE risk

// FLAG: @Nullable annotation inconsistency
private @Nullable ByteBuffer[] lastRows;  // But used with nullOrEmpty check
```

**Comment Template:**
```
The `{param}` parameter should be validated for null. Consider adding:
`Objects.requireNonNull({param}, "{param} is null");`

OR

The nullability annotation on `{field}` changed from '{before}' to '{after}'.
Consider whether this matches actual usage.
```

---

### Rule 6: Test Coverage Gaps

**ID**: `TEST_COVERAGE_001`
**Severity**: High
**Pattern**: Missing test scenarios

**Triggers:**
```java
// FLAG: Only testing one variant when multiple exist
@Test void testSyncMethod() { obj.doSync(); }
// Missing: testAsyncMethod for obj.doAsync()

// FLAG: Only one data point in distributed test
cluster.start(2);  // 2 nodes
table.put(1, "value");  // Only 1 key - insufficient for distribution test

// FLAG: Missing negative test
@Test void testValidInput() { ... }
// Missing: testInvalidInput, testNullInput, etc.
```

**Comment Template:**
```
The test only validates {scenario}. Consider adding test coverage for:
- {missing_scenario_1}
- {missing_scenario_2}

OR

You are using {nodeCount} nodes but only {keyCount} key(s). For distributed
testing, consider using more data to verify partition distribution.
```

---

### Rule 7: API Consistency

**ID**: `API_CONSISTENCY_001`
**Severity**: Medium
**Pattern**: Naming and design inconsistencies

**Triggers:**
```python
# FLAG: Non-idiomatic naming
def put(self, key, value):  # Python prefers 'set' for this pattern
    pass

# FLAG: Asymmetric naming
def set(self, value): ...
def get_and_put(self, value): ...  # Should be get_and_set for symmetry
```

```java
// FLAG: Inconsistent method signatures
void onReadHit(boolean readOnly);
void onReadMiss(boolean readOnly);
// Could be simplified to: void onRead(boolean hit, boolean readOnly)
```

**Comment Template:**
```
This method should be called `{suggested}` to be idiomatic in {language}.

OR

Consider using `{suggested_signature}` to simplify the API and reduce
duplicate code in callers.
```

---

### Rule 8: Build/Dependency Issues

**ID**: `BUILD_DEPS_001`
**Severity**: Medium
**Pattern**: Dependency version and configuration issues

**Triggers:**
```kotlin
// FLAG: Version specified for BOM-managed dependency
implementation("io.something:library:1.2.3")  // When BOM already manages version

// FLAG: Missing module documentation
// New module directory without README.md
```

**Comment Template:**
```
This dependency is managed by the BOM (`{bom}`), so the explicit version
`{version}` should be removed to avoid conflicts.

OR

Please add a README.md explaining the purpose of this new module.
```

---

### Rule 9: Upstream Coordination

**ID**: `UPSTREAM_001`
**Severity**: Medium
**Pattern**: Changes that should coordinate with Apache Ignite

**Triggers:**
```java
// FLAG: Modifying files in modules that exist in upstream
// modules/table/src/main/java/org/apache/ignite/...
// modules/sql-engine/src/main/java/org/apache/ignite/...

// FLAG: TODO without ticket reference
// TODO: fix this later  // Should reference IGNITE-XXXXX or GG-XXXXX
```

**Comment Template:**
```
This change modifies upstream code. Should this be contributed to Apache
Ignite first?

OR

Please add a ticket reference to this TODO: `// TODO: {TICKET_ID} {description}`
```

---

### Rule 10: Code Style (Supplemental)

**ID**: `STYLE_001`
**Severity**: Low
**Pattern**: Style issues not caught by Checkstyle

**Triggers:**
```java
// FLAG: Magic strings that should be constants
startUpgrade("{\"version\":\"9.9.9\"}");  // Extract to VERSION_TO_UPGRADE

// FLAG: Complex inline logic
if (isValidContext(ctx) && safeToInclude() && hasPermission(user) && ...) {
    // Should be extracted to a named method
}

// FLAG: Inconsistent indentation (spaces vs expected)
            line1;  // 13 spaces
           line2;  // 12 spaces - inconsistent
```

**Comment Template:**
```
Let's extract this to a constant: `private static final String {NAME} = "{value}";`

OR

This logic is complex. Consider extracting to a named method for clarity.
```

---

### Rule 11: C++ Header Self-Containment (Apache Ignite 3)

**ID**: `CPP_HEADERS_001`
**Severity**: High
**Pattern**: Headers missing necessary includes

**Triggers:**
```cpp
// FLAG: Using std::vector without including <vector>
std::vector<std::byte> data;  // But no #include <vector>

// FLAG: Using size_t without <cstddef>
size_t buf_size;  // But no #include <cstddef>

// FLAG: POSIX socket functions without proper headers
::socket(...);  // Missing #include <sys/socket.h>
::recv(...);    // Missing #include <sys/socket.h>
```

**Comment Template:**
```
The header uses `{type}` but doesn't include `{header}`. To make this header
self-contained and avoid relying on indirect includes, please add the
necessary standard headers.
```

---

### Rule 12: C++ Ownership Semantics (Apache Ignite 3)

**ID**: `CPP_OWNERSHIP_001`
**Severity**: Critical
**Pattern**: Resource-owning classes that are copyable

**Triggers:**
```cpp
// FLAG: Socket wrapper with default copy semantics
class socket_adapter {
    int m_fd;
public:
    void close() { ::close(m_fd); }
    // No deleted copy constructor - can double-close!
};

// FLAG: RAII class without move semantics
class resource_wrapper {
    Handle* handle;
    ~resource_wrapper() { release(handle); }
    // Copyable by default - dangerous!
};
```

**Comment Template:**
```
`{class}` is an owning wrapper around `{resource}` but is copyable. This can
lead to double-closing or use-after-close. Consider deleting the copy
constructor/assignment and adding move semantics:

```suggestion
{class}(const {class}&) = delete;
{class}& operator=(const {class}&) = delete;
{class}({class}&& other) noexcept : m_fd(other.m_fd) { other.m_fd = -1; }
```
```

---

### Rule 13: Shell Script Safety (Apache Ignite 3)

**ID**: `SHELL_SCRIPT_001`
**Severity**: Medium
**Pattern**: Shell scripts missing shebang or error handling

**Triggers:**
```bash
# FLAG: Missing shebang line
# Script starts with comments or commands, no #!/bin/bash

# FLAG: Commands that can fail without handling
odbcinst -u -d -n "Driver"  # If fails, package removal fails
# Should be: odbcinst ... || true

# FLAG: Hardcoded paths that should be configurable
/usr/lib/libignite.so  # Should use CMAKE_INSTALL_LIBDIR
```

**Comment Template:**
```
The shell script is missing a shebang line (#!/bin/bash or #!/bin/sh). Without
a shebang, the script may not execute correctly when called by package managers.

OR

The script lacks error handling. If `{command}` fails, the script will return
non-zero which could cause package removal to fail. Consider adding `|| true`
for best-effort cleanup.
```

---

### Rule 14: Integer Type Safety (Apache Ignite 3)

**ID**: `TYPE_SAFETY_001`
**Severity**: High
**Pattern**: Unsafe integer type conversions

**Triggers:**
```java
// FLAG: long to int without overflow check
long partitionId = getPartitionId();
return array[(int) partitionId];  // Overflow risk

// FLAG: Using manual range checking when standard method exists
if (longVal < Integer.MIN_VALUE || longVal > Integer.MAX_VALUE) {
    throw new ArithmeticException();
}
return (int) longVal;
// Better: Math.toIntExact(longVal)
```

```csharp
// FLAG: long array index in C#
long id = partition.Id;
return nodes[id];  // Compiler error or unsafe cast
// Use: checked((int)id)
```

**Comment Template:**
```
`{variable}` is a `long`, but `{array}` is indexed by `int`. Use
`Math.toIntExact({variable})` or explicit range validation to safely convert
with overflow checking.

OR

There is `Math.toIntExact` which might be simpler and faster.
```

---

### Rule 15: CMake Configuration (Apache Ignite 3)

**ID**: `CMAKE_CONFIG_001`
**Severity**: Medium
**Pattern**: CMake packaging and configuration issues

**Triggers:**
```cmake
# FLAG: ExactVersion compatibility (too restrictive)
write_basic_package_version_file(... COMPATIBILITY ExactVersion)
# Should be SameMajorVersion for libraries

# FLAG: Install path computed incorrectly
set(INCLUDE_DIR "../")  # Relative from wrong base
# Should use PACKAGE_PREFIX_DIR

# FLAG: Duplicate file installation
install(FILES config.cmake DESTINATION cmake COMPONENT client)
install(FILES config.cmake DESTINATION cmake COMPONENT odbc)  # Duplicate!
```

**Comment Template:**
```
The version compatibility is set to ExactVersion, which is extremely
restrictive. For a library, SameMajorVersion would be more appropriate,
allowing patch and minor version updates.

OR

The config files are being installed twice with different components. This
creates duplicate files. Consider using a single install rule.
```

---

### Rule 16: Logging Configuration (Apache Ignite 3)

**ID**: `LOGGING_001`
**Severity**: Medium
**Pattern**: Incorrect logging configuration

**Triggers:**
```java
// FLAG: Logger level mismatch
if (throttledLogger.isDebugEnabled()) {
    throttledLogger.warn(...);  // Checking debug, logging warn
}

// FLAG: Allow-list instead of block-list for error logging
if (ERROR_CODES_TO_LOG.contains(code)) {
    log.error(msg);  // Only logs known codes - misses unexpected errors
}

// FLAG: Cache key collision risk
String key = connectionId + opCode;  // "1" + "12" == "11" + "2"
// Better: connectionId + ":" + opCode
```

**Comment Template:**
```
Should we change logger level check to WARN? Logging with WARN severity when
only debug is enabled is a bit misleading.

OR

This uses an allow-list for error logging, which means unexpected exceptions
won't be logged. Any unexpected exception should be logged. We should have a
block-list, not an allow-list.
```

---

### Rule 17: Code Duplication (Apache Ignite 3)

**ID**: `CODE_DUP_001`
**Severity**: Medium
**Pattern**: Duplicate implementations that should be shared

**Triggers:**
```java
// FLAG: Same utility methods in multiple classes
class A {
    private static byte castToByte(Number n) { ... }  // 20 lines
}
class B {
    private static byte castToByte(Number n) { ... }  // Same 20 lines
}
```

**Comment Template:**
```
The `{method}` methods are duplicated across `{class1}` and `{class2}` with
identical implementations. Consider extracting these methods into a shared
utility class to avoid code duplication and ensure consistent behavior.
```

---

### Rule 18: Test Assertions (Apache Ignite 3)

**ID**: `TEST_ASSERT_001`
**Severity**: Low
**Pattern**: Suboptimal test assertions

**Triggers:**
```java
// FLAG: Manual comparison instead of matcher
assertTrue(result <= expected);
// Better: assertThat(result, lessThanOrEqualTo(expected))

// FLAG: Testing only dimensions, not content
assertEquals(3, result.size());
// Should also verify actual content

// FLAG: Testing with disabled config expecting behavior
config.setEnabled(false);
result = processor.process(input);  // What's the point?
```

**Comment Template:**
```
These asserts could be better expressed using `Matchers.lessThanOrEqualTo`.

OR

Can we also test the result of the operation, not only the dimensions?

OR

You test with DISABLED config. This doesn't make sense - the feature is disabled.
```

---

### Rule 19: Input Validation (Extended Analysis)

**ID**: `INPUT_VALIDATION_001`
**Severity**: Medium
**Pattern**: Missing input sanitization

**Triggers:**
```java
// FLAG: Split without trim
String[] fields = input.split(",");  // "a, b" -> ["a", " b"]
// Should be: Arrays.stream(input.split(",")).map(String::trim)...

// FLAG: Assertion instead of validation
assert model != null;  // Can be disabled at runtime!
// Should be: if (model == null) throw new IllegalStateException(...)
```

**Comment Template:**
```
Field names should be trimmed after splitting to handle whitespace around commas.
Users may write 'field1, field2' with spaces. Use
`Arrays.stream(str.split(",")).map(String::trim).collect(...)`.

OR

Replace assertion with proper null check and exception handling. Assertions can
be disabled at runtime and may not provide adequate error handling in production.
```

---

### Rule 20: Exception Message Quality (Extended Analysis)

**ID**: `EXCEPTION_MSG_001`
**Severity**: Low
**Pattern**: Generic or misleading exception messages

**Triggers:**
```java
// FLAG: Generic message
throw new UnsupportedOperationException("This method should not be called.");
// Should include method name

// FLAG: Wrong type in message
// In readDoubleValue method:
throw new ClassCastException("Cannot convert to " + ColumnType.FLOAT);  // Should be DOUBLE
```

**Comment Template:**
```
All UnsupportedOperationException messages use generic "This method should not be
called." Consider making these messages more specific by including the method name
to aid debugging, e.g., "{methodName}() should not be called on {className}."

OR

The exception message incorrectly references `{wrong}` when it should reference
`{correct}`. This will produce misleading error messages.
```

---

### Rule 21: Test Logic Errors (Extended Analysis)

**ID**: `TEST_LOGIC_001`
**Severity**: High
**Pattern**: Bugs in test code

**Triggers:**
```java
// FLAG: Same index used twice
for (int i = 0; i < 2; i++) {
    check(nodes.get(0));  // Should be nodes.get(i)
}

// FLAG: Dead code in test
if (false) {  // Condition always false
    verify(...);
}

// FLAG: Missing assertions
@Test void testSomething() {
    doOperation();
    // No assertions!
}
```

**Comment Template:**
```
This checks first node twice - the loop variable is not used.

OR

This condition is always `false` and this block can be removed.

OR

Perhaps I am missing something important, but I don't see any assertions in this
test. How do you verify the expected behavior?
```

---

## Comment Formatting

### With Code Suggestion

Use GitHub's suggestion format:
````markdown
{Description of issue and why it matters}
```suggestion
{corrected code}
```
````

### Without Code Suggestion

```markdown
{Description of issue}

{Why it's a problem}

{Suggested approach - be specific}
```

### Questions/Clarifications

```markdown
{Question}?

OR

Why {observed behavior}? {Expected behavior explanation if needed}
```

---

## Confidence Thresholds

Only comment when confidence is high enough:

| Issue Type | Minimum Confidence |
|------------|-------------------|
| Definite bugs (NPE, race conditions) | 80% |
| Potential issues | 90% |
| Style/clarity suggestions | 95% |
| Nitpicks | 99% |

If uncertain, phrase as a question:
```markdown
This looks like it might cause {issue}. Can you confirm whether {assumption}
is correct here?
```

---

## Review Workflow

1. **First Pass**: Critical and High severity issues only
2. **Second Pass**: Medium severity issues
3. **Third Pass**: Low severity / nitpicks (limit to 3-5 per PR)

**Do NOT**:
- Flag issues in generated code
- Repeat similar comments more than twice
- Comment on vendored third-party code
- Suggest major refactoring for small PRs
- Flag style issues that Checkstyle/SpotBugs will catch

---

## Example Review Session

For a PR touching `modules/table/src/main/java/.../SomeClass.java`:

1. Check for thread safety issues in concurrent code paths
2. Verify resource cleanup in `close()` methods
3. Validate null handling for public API parameters
4. Check Javadoc accuracy for public methods
5. Verify test coverage for new/modified functionality
6. Check for upstream coordination needs (Apache Ignite)
7. Review for dead code or debug artifacts
8. Suggest constant extraction for magic values

Output comments in order of severity (Critical → High → Medium → Low).
