part of thread;

class ThreadInitialState {
  final SendPort sendPort;
  final void Function(EventEmitter emitter) eventHandler;

  const ThreadInitialState(this.sendPort, this.eventHandler);
}

class ThreadComputeRequest<ReturnType> {
  final dynamic data;
  final ReturnType Function(dynamic data) callback;
  ThreadComputeRequest(this.data, this.callback);
}