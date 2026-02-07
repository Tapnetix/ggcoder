---
name: test-patterns
description: Use when reviewing or fixing test code - assertions, coverage, Hamcrest matchers, Awaitility in GridGain/Ignite tests
---

# Test Patterns for GridGain/Ignite

## From PR Mining

Key patterns from test stability PRs #3639, #3604, #3576:

---

## Pattern 1: Hamcrest Matchers

```java
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;

assertThat(result, is(expected));
assertThat(result, lessThanOrEqualTo(expected));
assertThat(list, hasSize(3));
```

---

## Pattern 2: Custom Future Matchers

```java
assertThat(future, willBe(expectedValue));
assertThat(future, willCompleteSuccessfully());
assertThat(future, willThrow(IllegalStateException.class));
```

---

## Pattern 3: Test Both Variants

```java
@Test void testSyncDestroy() {
    table.destroy();
    assertThat(tableExists(name), is(false));
}

@Test void testAsyncDestroy() {
    assertThat(table.destroyAsync(), willCompleteSuccessfully());
    assertThat(tableExists(name), is(false));
}
```

---

## Pattern 4: Awaitility for Async (from PR #3576)

```java
await().atMost(10, TimeUnit.SECONDS)
    .until(() -> getNodeCount(), is(3));
```

**Anti-pattern**: `Thread.sleep(5000)` - slow and flaky

---

## Pattern 5: Distributed Test Data

```java
// BAD: Single key doesn't test distribution
cluster.start(2);
table.put(1, "value");

// GOOD: Enough data for partition distribution
for (int i = 0; i < 100; i++) {
    table.put(i, "value-" + i);
}
```

---

## Review Checklist

- [ ] Uses Hamcrest matchers
- [ ] Tests sync AND async variants
- [ ] Loop variables actually used
- [ ] Uses Awaitility, not Thread.sleep
- [ ] Distributed tests use sufficient data
