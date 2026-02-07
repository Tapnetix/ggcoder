---
name: security-context-patterns
description: Use when reviewing security-sensitive code - context propagation, credentials, RLS
---

# Security Context Patterns for GridGain/Ignite

## From GridGain-9 PR Mining

Key patterns from PRs #3564, #3586.

## Pattern 1: SecurityContextHolder.set()

```java
// Before operations requiring security context
SecurityContextHolder.set(securityContext);
try {
    performSecureOperation();
} finally {
    SecurityContextHolder.clear();
}
```

## Pattern 2: Version-Conditional Credentials

```java
// Check version before including credentials
if (cmgManager.getClusterVersion().compareTo(MIN_VERSION) >= 0) {
    request.setCredentials(credentials);
}
```

## Checklist

- [ ] SecurityContextHolder.set() before secure ops
- [ ] Version check before credentials in requests
- [ ] Integration tests for security paths
