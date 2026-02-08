---
name: concurrency-patterns
description: "You MUST invoke this when working with concurrent/multithreaded code, especially in GridGain/Ignite. Triggers: HashMap in shared context, race condition, thread-safe, synchronized, volatile, ConcurrentHashMap, deadlock, lock ordering, AtomicReference, executor, parallel streams. Invoke BEFORE suggesting thread-safety fixes."
---

# Concurrency Patterns for GridGain/Ignite

## Critical Rules (from CODE_REVIEW_GUIDELINES.md)

### Rule 1: Thread Safety Violations
**Severity**: Critical | **Confidence Threshold**: 80%

**Triggers**:
- Field written in synchronized method, read outside
- Non-atomic check-then-act sequences
- Concurrent access to non-thread-safe collections

---

## Pattern 1: Double-Checked Locking with Volatile

**When to use**: Lazy initialization, singletons, cached computations

```java
public class Lazy<T> {
    private volatile Supplier<T> supplier;

    @SuppressWarnings("FieldAccessedSynchronizedAndUnsynchronized")
    private @Nullable T val;

    public @Nullable T get() {
        T v = val;  // Single read into local

        if (v == null) {
            if (supplier != EMPTY) {
                synchronized (this) {
                    if (supplier != EMPTY) {  // Double-check
                        v = supplier.get();
                        val = v;
                        supplier = (Supplier<T>) EMPTY;
                    }
                }
            }
            v = val;
        }
        return v;
    }
}
```

**Key points**:
- `volatile` on supplier for visibility
- Single read of volatile into local variable
- Double-check inside synchronized block

---

## Pattern 2: Private Lock Objects

**When to use**: Any synchronized access to shared state

```java
private final Object lock = new Object();
private volatile boolean cancelled = false;

public void doWork() {
    synchronized (lock) {
        if (cancelled) throw new CancelledException();
        state = newState;
    }
    // Async work OUTSIDE lock
    processAsync(state);
}
```

**Anti-pattern**: `synchronized(this)` exposes to external interference

---

## Pattern 3: Volatile Boolean Flags

**When to use**: Lifecycle/cancellation flags

```java
private volatile boolean cancelled = false;
private volatile boolean finished = false;
```

---

## Review Checklist

- [ ] Shared mutable fields are volatile or synchronized
- [ ] Uses private lock objects, not `this`
- [ ] Check-then-act inside synchronized blocks
- [ ] Volatile reads captured in local before multiple uses
- [ ] Expensive operations outside synchronized blocks

## Fix Templates

### Adding Volatile
```java
// Before
private boolean flag;

// After
private volatile boolean flag;
```

### Converting to Private Lock
```java
// Before
public synchronized void method() { ... }

// After
private final Object lock = new Object();
public void method() {
    synchronized (lock) { ... }
}
```
