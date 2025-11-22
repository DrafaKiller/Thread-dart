import 'dart:async';
import 'dart:isolate';

import 'package:events_emitter/events_emitter.dart';
import 'package:stream_channel/isolate_channel.dart';

class ThreadPayload {
  const ThreadPayload(this.sendPort, [ this.eventHandler ]);

  final SendPort sendPort;
  final EventHandler? eventHandler;
}

typedef EventHandler = void Function(EventEmitter events);
typedef ThreadChannel = IsolateChannel<ThreadEvent>;

class ThreadState {
  const ThreadState(this.isolate, this.channel);

  final Isolate isolate;
  final ThreadChannel channel;

  /* -= Static =- */

  static Future<ThreadState> create(EventHandler? handler) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_entryPoint, ThreadPayload(receivePort.sendPort, handler));
    final channel = ThreadChannel.connectReceive(receivePort);
    return ThreadState(isolate, channel);
  }

  static void _entryPoint(ThreadPayload payload) {
    final channel = ThreadChannel.connectSend(payload.sendPort);
    final events = AsyncEventEmitter(channel.stream, channel.sink);
  }
}





class AsyncEventEmitter extends EventEmitter {
  AsyncEventEmitter(this._stream, this._sink) {
    _stream.listen((event) => super.emitEvent(event));
  }

  final Stream<Event> _stream;
  final StreamSink<Event> _sink;

  @override
  bool emitEvent<T extends Event>(T event) {
    _sink.add(event);
    return true;
  }
}













class Thread {
  final Isolate? isolate;
  final ThreadChannel? channel;

  
}

class ThreadController {

}

class ThreadEvent<T> {
  
}
