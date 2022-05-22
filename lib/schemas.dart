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
    emitter.emit(topic,
      // The warning is wrong, the callback can be async/Future, it still needs `await`, it will not work if it doesn't.
      // ignore: await_only_futures
      await callback(data)
    );
  }
}