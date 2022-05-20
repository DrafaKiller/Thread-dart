import 'package:thread/thread.dart';

void main() async {
  final thread = IsolateThread((emitter) {
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
}