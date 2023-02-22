part of '../thread.dart';

typedef EventHandler = void Function(EventEmitter events);

class ThreadInitialState {
  final SendPort sendPort;
  final EventHandler? eventHandler;

  const ThreadInitialState(this.sendPort, this.eventHandler);
}
