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
  void emit<MessageType>(String topic, MessageType data) {
    if (topic == 'end' && data is bool) {
      super.emit<MessageType>(topic, data);
    }
    sendPort.send(Event<MessageType>(topic, data));
  }

  Future<void> untilEnd() async {
    final until = Completer();

    on('end', (bool exit) {
      if (exit) until.complete();
    });

    await until.future;
  }
}