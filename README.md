[![Pub.dev package](https://img.shields.io/badge/pub.dev-thread-blue)](https://pub.dev/packages/thread)
[![GitHub repository](https://img.shields.io/badge/GitHub-Thread--dart-blue?logo=github)](https://github.com/DrafaKiller/Thread-dart)

# Thread

A simple Isolated Thread wrapped with a type-safe Event Emitter for easier asynchronous communication.

Setup events for the thread to reply, or compute tasks individually.

## Features

- Simple thread setup, control and communication
- Type-safe communication between threads
- Setup thread callbacks, using thread events
- Compute tasks individually

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

Setup a thread along with the initial function that will be running with it.

```dart
final thread = Thread((events) {
    ...
});

// Create a thread with no initial function
final thread = Thread.empty();
```

The thread will start automatically but you can prevent it from starting by setting the `start` parameter to false.

Inside the initial function, use the given **EventEmitter** to communicate. To make the most out of it, make sure to read the [documentation here](https://pub.dev/packages/events_emitter).

```dart
final thread = Thread((events) {
    events.on('data', (String data) async {
        ...
        events.emit('result', '<Computed> $data');
    });
});
```

Listen for the result outside the thread, and emit data whenever you need to compute something. Always emit thread-safe data.

```dart
thread.on('result', (String data) => print(data));

thread.emit('data', 'Hello World');

// [Output]
// <Computed> Hello World
```

You can also compute tasks individually with no setup needed. Tasks like this can be asynchronous, the result will be returned as a future.

The computation function will be executed in the thread, make sure to not use any objects that are not thread-safe.

```dart
// Send a single task for the thread to execute
print(await thread.compute(() => '<Computed> Hello World'));

// Compute a task along some input data
print(await thread.computeWith('Hello World', (String data) {
    return '<Computed> $data';
}));

// [Output]
// <Computed> Hello World
```

## Controlling a Thread

Threads start automatically when you create them, the emitted events will be handled by the thread after starting.

You can also start it manually, make sure to set the `start` parameter to false.

```dart
final thread = Thread((events) { ... }, start: false);

await thread.start();
 ...
```

Stop the thread by using `thread.stop()` or `thread.emit('end', true)`.

Start another isolated thread with the same object by using `thread.start()`, but only if the thread is not already alive.

A Thread execution can also be paused and resumed, using `thread.pause()` and `thread.resume()`.

## Addtional Methods

A temporary thread can be started with `Thread.Compute` and `Thread.ComputeWith` to compute a single task and return the result.

```dart
final computed = await Thread.Compute(() => '<Computed> Hello World');
final compute2 = await Thread.ComputeWith('Test', (String data) =>  '<Computed> $data');

print(computed);
print(compute2);

// [Output]
// <Computed> Hello World
// <Computed> Test
```

> Careful when starting threads too quickly, starting a thread can be performance intensive. These methods should only be used when necessary, as in one time situation. Often is better to keep a single thread constantly open and idle.

## GitHub

The package code is available on Github: [Dart - Thread](https://github.com/DrafaKiller/Thread-dart)

## Example

```dart
import 'package:thread/thread.dart';

void main() async {
  final thread = Thread((events) {
    events.on('data', (String data) async {
      await Future.delayed(const Duration(seconds: 1));
      events.emit('result', '<Computed> $data');
    });
  });

  thread.on('result', (String data) => print(data));

  thread.emit('data', 'Hello world!');
  thread.emit('data', 'Wow!');

  print(await thread.compute(() => 'Hello world!'));
  print(await thread.computeWith(123, (int data) => 'Wow $data'));

  // [Output]
  // Hello world!
  // Wow 123

  // <Computed> Hello world!
  // <Computed> Wow!
}
```