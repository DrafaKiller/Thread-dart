// ignore_for_file: avoid_print

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
