import 'dart:async';
import 'dart:isolate';

import 'package:async_signal/async_signal.dart';
import 'package:events_emitter/events_emitter.dart';
import 'package:stream_channel/isolate_channel.dart';
import 'package:thread/event_emitter.dart';
import 'package:uuid/uuid.dart';

part 'errors.dart';
part 'components/request.dart';
part 'components/state.dart';

const uuid = Uuid();

class ThreadController {

}

class Thread {
  Isolate? isolate;
  final EventHandler? _eventHandler;

  final _signal = AsyncSignal(locked: true);
  
  ThreadEventEmitter? events;

  final _deadListeners = <EventListener>[];
  
  bool get alive => isolate != null;
  bool get initialized => alive && events != null;
  Thread(this._eventHandler, { bool start = true }) {
    if (start) this.start();
  }

  factory Thread.empty({ bool start = true }) => Thread(null, start: start);

  Future<void> start() async {
    if (alive) return;
    final receivePort = ReceivePort();
    isolate = await Isolate.spawn(
      _entryPoint, 
      ThreadInitialState(receivePort.sendPort, _eventHandler),
      debugName: 'ThreadIsolate-${uuid.v4()}',
    );

    final channel = IsolateChannel.connectReceive(receivePort);

    final receiveStream = receivePort.asBroadcastStream();
    final sendPort = await receiveStream.first;
    if (sendPort is SendPort) {
      events = ThreadEventEmitter(receivePort, sendPort, receiveStream: receiveStream);
      events!.listeners.addAll(_deadListeners);
      _deadListeners.clear();
      _signal.unlock();
    } else {
      stop();
      throw InvalidThreadSendPortException();
    }
  }

  void stop({ int priority = Isolate.immediate }) {
    if (!alive) return;
    isolate?.kill(priority: priority);
    isolate = null;
    events?.off();
    events = null;
    _signal.lock();
  }

  void pause() => isolate?.pause(isolate?.pauseCapability);

  void resume() => isolate?.resume(isolate!.pauseCapability!);

  FutureOr<void> untilAlive() async {
    if (initialized) return;
    await _signal.wait();
  }

  /* -= Compute Methods =- */

  Future<ReturnT> compute<ReturnT>(EmptyComputeCallback<ReturnT> computation) {
    return computeWith(null, (void data) => computation());
  }

  Future<ReturnT> computeWith<EntryT, ReturnT>(EntryT data, ComputeCallback<EntryT, ReturnT> computation) async {
    final id = uuid.v4();
    final result = once(id, (ReturnT data) {});
    emit(id, ThreadComputeRequest(id, data, computation));
    return result;
  }

  /* -= Event Methods =- */

  EventListener<T> onAny<T>(EventCallback<T> callback) {
    if (events != null) return events!.onAny(callback);

    final listener = EventListener<T>(null, callback);
    _deadListeners.add(listener);
    return listener;
  }

  EventListener<T> on<T>(String? type, EventCallback<T> callback) {
    if (events != null) return events!.on(type, callback);

    final listener = EventListener<T>(type, callback);
    _deadListeners.add(listener); 
    return listener;
  }


  Future<T> once<T>(String? type, EventCallback<T> callback) async {
    await _signal.wait();
    return events!.once(type, callback);
  }

  Future<void> emit<T>(String type, [ T? data ]) async {
    await untilAlive();
    events!.emit(type, data);
  }
  
  Future<void> emitEvent<T extends Event>(T event) async {
    await untilAlive();
    events!.emitEvent(event);
  }

  /* -= Static Methods =- */

  static Future<void> _entryPoint(ThreadInitialState initialState) async {
    final receivePort = ReceivePort();
    initialState.sendPort.send(receivePort.sendPort);

    final events = ThreadEventEmitter(receivePort, initialState.sendPort);
    initialState.eventHandler?.call(events);
    events.onAny((ThreadComputeRequest event) => event.compute(event.type, events));

    await events.untilEnd();
  }

  // ignore: non_constant_identifier_names
  static Future<ReturnT> Compute<ReturnT>(ReturnT Function() computation) async {
    final thread = Thread.empty();
    final result = await thread.compute(computation);
    thread.stop();
    return result;
  }

  // ignore: non_constant_identifier_names
  static Future<ReturnT> ComputeWith<EntryT, ReturnT>(EntryT data, ComputeCallback<EntryT, ReturnT> computation) async {
    final thread = Thread.empty();
    final result = await thread.computeWith(data, computation);
    thread.stop();
    return result;
  }
}
