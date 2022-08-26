## 0.2.1

Fixed:
- **Thread** `.emit()` is optional, updated because of `events_emitter` dependency

## 0.2.0

Added:
- `pause` and `resume` methods, to allow pausing and resuming the execution of the thread. This is the same as doing `thread.isolate.pause()`.
- `untilAlive` method, to wait until the thread is alive
- `Thread.Compute` and `Thread.ComputeWith` methods, to create a temporary thread, execute a single task on it and return the result
- `lint` developer dependency

**`[!]`** Changed:
- **Thread** property `eventHandler` is private
- **Thread** property `receivePort` is internal
- Renamed **Thread** property `emitter` to `events`, it's an easier term to understand
- Renamed **Thread** property `running` to `alive`, it's more accurate to what represents
- Renamed **ThreadComputeRequest** property `callback` to `computation`
- Renamed file `schemas.dart` to `others.dart`
- ChangeLog's format
- Improved documentation

Fixed:
- `thread.stop()` and then `thread.start()` would cause an exception for reusing the same ReceivePort
- Basic lint errors

**`[!]`** Removed:
- `keepEmitsWhileNotRunning` from **Thread** class, now it always preserves the emits

BREAKING CHANGES:
> The Thread was partially **refactored**, and updated to use the new version of the `events_emitter` dependency. Although it's essentially the same, be aware the way events work might have changed, depending on your case.
> 
> Changes: **`[!]`**

## 0.1.2

Fixed:
- `events_emitter` now returns a listener instead of a subscription

## 0.1.1

Changed:
- `events_emitter` and `async_signal` dependency versions to lastest

## 0.1.0

Added:
- `shields.io` badges in documentation
Removed:
- `flutter` from package dependency

## 0.0.3

Changed:
- Optional `eventEmitter` in **Thread**

Fixed:
- Wrong event `type`, in some cases

## 0.0.2

Changed:
- Renamed **IsolatedThread** class to **Thread**

## 0.0.1

Initial release: Thread