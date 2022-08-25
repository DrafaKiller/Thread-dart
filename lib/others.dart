part of thread;

class ThreadInitialState {
  final SendPort sendPort;
  final EventHandler? eventHandler;

  const ThreadInitialState(this.sendPort, this.eventHandler);
}

class ThreadComputeRequest<EntryT, ReturnT> extends Event<EntryT> {
  final ComputeCallback<EntryT, ReturnT> computation;
  ThreadComputeRequest(super.type, super.data, this.computation);

  Future<void> compute(String topic, EventEmitter events) async {
    // The warning is wrong, the callback can be async/Future, it still needs `await`, it will not work if it doesn't.
    // ignore: await_only_futures
    events.emit(topic, await computation(data));
  }
}

typedef EventHandler = void Function(EventEmitter events);
typedef EntryPoint = void Function();
typedef ComputeCallback<EntryT, ReturnT> = ReturnT Function(EntryT data);
