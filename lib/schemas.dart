part of thread;

class ThreadInitialState {
  final SendPort sendPort;
  final void Function(EventEmitter emitter)? eventHandler;

  const ThreadInitialState(this.sendPort, this.eventHandler);
}

class ThreadComputeRequest<EntryType, ReturnType> {
  final EntryType data;
  final ReturnType Function(EntryType data) callback;
  ThreadComputeRequest(this.data, this.callback);

  void compute(String topic, EventEmitter emitter) async {
    // ignore: await_only_futures
    emitter.emit(topic, await callback(data)); // The warning is wrong, the callback can be async/Future, it still needs `await`.
  }
}