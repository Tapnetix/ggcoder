---
name: async-patterns
description: "Invoke when code uses async/reactive patterns in GridGain/Ignite. Triggers: CompletableFuture, CompletionStage, Publisher, Subscriber, Flow, Channel, async callback, thenApply, whenComplete, exceptionally, backpressure. Invoke BEFORE fixing async code."
---

# Async Patterns for GridGain/Ignite

## From PR Mining (GridGain-9)

Key patterns from Continuous Query PRs #3565, #3588, #3592:

---

## Pattern 1: CompletableFuture Chaining

```java
prev.thenCompose(tmp -> cursorFut)
    .thenAcceptAsync(cursor -> {
        process(cursor);
        next.complete(result);
    }, exec)
    .exceptionally(t -> {
        next.completeExceptionally(t);
        return null;
    });
```

**Key**: Use `thenCompose` (not `thenApply`) for future chaining

---

## Pattern 2: Channel-Based Producer-Consumer (from PR #3592)

```csharp
var channel = Channel.CreateBounded<T>(new BoundedChannelOptions(capacity) {
    FullMode = BoundedChannelFullMode.Wait
});

// Producer with exception propagation
Task.Run(async () => {
    try {
        await foreach (var item in ScanPartition(partition)) {
            await channel.Writer.WriteAsync(item);
        }
    } catch (Exception ex) {
        channel.Writer.Complete(ex);  // Propagate error!
    }
});
```

---

## Pattern 3: Protocol Feature Flags (from PR #3588)

```java
public static final ClientProtocolFeature CQ_LONG_POLLING_WAIT_TIME =
    new ClientProtocolFeature(42);

public void serialize(PayloadWriter writer, ProtocolVersion version) {
    if (version.supports(CQ_LONG_POLLING_WAIT_TIME)) {
        writer.writeLong(longPollingWaitTimeMs);
    }
}
```

---

## Pattern 4: Async Cancellation

```java
public CompletableFuture<Void> cancelAsync() {
    if (!cancelled) {
        synchronized (lock) {
            if (!cancelled) {
                pendingFuture.completeExceptionally(new CancelledException());
                cancelled = true;
                cancelFut.complete(null);
            }
        }
    }
    return cancelFut;
}
```

---

## Review Checklist

- [ ] Exceptions propagated through async chains
- [ ] `thenCompose` for future chaining, not `thenApply`
- [ ] Bounded channels/queues for backpressure
- [ ] Background tasks propagate errors
- [ ] Protocol features have version checks
