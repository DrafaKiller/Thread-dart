part of thread;

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
  bool emit<T>(String type, T data) {
    if (type == 'end' && data is bool) super.emit<T>(type, data);
    sendPort.send(Event<T>(type, data));
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
