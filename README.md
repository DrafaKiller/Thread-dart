[![Pub.dev package](https://img.shields.io/badge/pub.dev-thread-blue)](https://pub.dev/packages/thread)
[![GitHub repository](https://img.shields.io/badge/GitHub-Thread--dart-blue?logo=github)](https://github.com/DrafaKiller/Thread-dart)

# Thread

A simple Isolated Thread wrapped with a type-safe Event Emitter for easier asynchronous communication.

Setup events for the thread to reply to, or compute tasks individually.

## Getting started

Install it using pub:
```
dart pub add thread
```

And import the package:
```dart
import 'package:thread/thread.dart';
```

## Usage

Setup a thread along with a function that will be running with it.
```dart
final thread = Thread((emitter) {
    ...
});

// Create a thread with no initial function
final thread = Thread.empty();
```

Inside the function, use the given Event Emitter to communicate.
```dart
final thread = Thread((emitter) {
    emitter.on('do this', (String data) async {
        /// ...
        emitter.emit('done', '[Computed] $data');
    });
});
```

Listen for the result outside the thread and send a signal whenever you need it.
```dart
thread.on('done', (String data) {
    print(data);
});

thread.emit('do this', 'Hello World');

// [Output]
// [Computed] Hello World
```

There are also signals to compute tasks individually with no setup needed. These tasks can be asynchronous.
```dart
// Send a single task for the thread to run
print(await thread.compute(() => '[Computed] Hello World'));

// Compute a task along some input dat
print(await thread.computeWith('Hello World', (String data) {
    return '[Computed] $data';
}));

// [Output]
// [Computed] Hello World
```

The thread starts automatically when you create it, the emitted events will be handled by the thread after started. But you can also start it manually.
```dart
final thread = Thread((emitter) {
    ...
}, start: false, keepEmitsWhileNotRunning: false);

await thread.start();

thread.emit( ... );
```

Stop the thread by using `thread.stop()` or `emitter.emit('end', true)`, you can start another isolated thread with the same object by using `thread.start()`, but only if the thread is not already running.

## GitHub

The package code is available on Github: [Dart - Thread](https://github.com/DrafaKiller/Thread-dart)

## Example

```dart
final thread = Thread((emitter) {
    emitter.on('compute', (String data) async {
        await Future.delayed(const Duration(seconds: 1));
        emitter.emit('result', '[Computed] $data');
    });
});

thread.on('result', (String data) => print(data));

thread.emit('compute', 'Hello world!');
thread.emit('compute', 'Wow!');

print(await thread.compute(() => 'Hello world!'));
print(await thread.computeWith(123, (int data) => 'Wow $data'));

// [Output]
// [Computed] Hello world!
// [Computed] Wow!

// Hello world!
// Wow 123
```