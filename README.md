# Thread

A simple Isolated Thread wrapped with a type-safe Event Emitter for easier communication.

## Features

* ...

## Getting started

Install it using pub:
```
flutter pub add thread
```

And import the package:
```dart
import 'package:thread/thread.dart';
```

## Usage

... 

## GitHub

The package code is available on Github: [Dart - Thread](https://github.com/DrafaKiller/Thread-dart)

## Example

```dart
final thread = IsolateThread((emitter) {
    emitter.on('compute', (String data) async {
        await Future.delayed(const Duration(seconds: 1));
        emitter.emit('result', '[Computed] $data');
    });
});

thread.on('result', (String data) => print(data));
await thread.start();

thread.emit('compute', 'Hello world!');
thread.emit('compute', 'This is a test message');
thread.emit('compute', 'Wow!');

print(await thread.compute(() => 'Hello world!'));
print(await thread.compute(123, (data) => 'Wow $data'));

// [Output]
// [Computed] Hello world!
// [Computed] This is a test message
// [Computed] Wow!

// Hello world!
// Wow 123
```