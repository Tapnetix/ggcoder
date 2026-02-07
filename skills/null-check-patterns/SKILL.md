---
name: null-check-patterns
description: Use when reviewing or fixing null safety - parameter validation, @Nullable annotations, Objects.requireNonNull in GridGain/Ignite code
---

# Null Check Patterns for GridGain/Ignite

## Rule 5: Null Safety
**Severity**: High | **Confidence Threshold**: 80%

---

## Pattern 1: Objects.requireNonNull with Message

```java
public void process(String key, Object value) {
    Objects.requireNonNull(key, "key");
    Objects.requireNonNull(value, "value");
    // ...
}

// Constructor pattern
public MyClass(Service service) {
    this.service = Objects.requireNonNull(service, "service");
}

// Chained pattern
return forName(Objects.requireNonNull(cls, "cls").getName());
```

---

## Pattern 2: @Nullable Annotations

```java
import org.jetbrains.annotations.Nullable;

private @Nullable T val;
public @Nullable T get() { ... }
public Lazy(Supplier<@Nullable T> supplier) { ... }
```

---

## Pattern 3: Collection Validation

```java
public void processItems(Collection<String> items) {
    Objects.requireNonNull(items, "items");
    for (String item : items) {
        Objects.requireNonNull(item, "item");
    }
}
```

---

## Pattern 4: Null-Safe Close

```java
public void stop() {
    if (server != null) {
        server.shutdown();
    }
}
```

---

## Review Checklist

- [ ] Public method parameters validated with Objects.requireNonNull
- [ ] Validation includes descriptive message
- [ ] Validation at method entry, before work
- [ ] @Nullable annotations match actual nullability
- [ ] close()/stop() methods handle null resources
