import 'dart:async';
import 'dart:isolate';

import 'package:events_emitter/events_emitter.dart';

class ThreadEventEmitter extends EventEmitter {
  final ReceivePort receivePort;
  final SendPort sendPort;

  final Stream receiveStream;

  ThreadEventEmitter(this.receivePort, this.sendPort, { Stream? receiveStream }) :
    receiveStream = receiveStream ?? receivePort.asBroadcastStream()
  {
    this.receiveStream.listen((event) {
      if (event is Event) super.emitEvent(event);
    });
  }

  @override
  bool emitEvent<T extends Event>(T event) {
    if (event.type == 'end' && event.data is bool) super.emitEvent<T>(event);
    sendPort.send(event);
    return true;
  }

  Future<void> untilEnd() async {
    final until = Completer();
    on('end', (bool exit) {
      if (exit) until.complete();
    });
    await until.future;
  }
}
