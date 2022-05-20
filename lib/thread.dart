library thread;

import 'dart:async';
import 'dart:isolate';

import 'package:events_emitter/events_emitter.dart';
import 'package:async_signal/async_signal.dart';
import 'package:uuid/uuid.dart';

part 'thread_event_emitter.dart';
part 'schemas.dart';

class IsolateThread {
  final _threadEmitter = EventEmitter();
  Isolate? isolate;
  final bool keepEmitsWhileNotRunning;
  final _uuid = const Uuid();

  final ReceivePort receivePort = ReceivePort();
  ThreadEventEmitter? emitter;

  final void Function(EventEmitter emitter) eventHandler;

  final _emitSignal = AsyncSignal(locked: true);
  bool get running => !_emitSignal.locked;

  IsolateThread(this.eventHandler, { bool start = true, this.keepEmitsWhileNotRunning = true }) {
    if (start) this.start();
  }

  IsolateThread.empty({ bool start = true, this.keepEmitsWhileNotRunning = true }) :
    eventHandler = ((emitter) {})
  {
    if (start) this.start();
  }
  
  Future<void> start() async {
    if (running) return;

    final initialState = ThreadInitialState(receivePort.sendPort, eventHandler);
    isolate = await Isolate.spawn(_onEntryPoint, initialState);

    final receiveStream = receivePort.asBroadcastStream();   

    final data = await receiveStream.first;
    if (data is SendPort) {
      emitter = ThreadEventEmitter(receivePort, data, receiveStream: receiveStream);
      emitter!.onAny((event) => _threadEmitter.emit(event.topic, event.message));
      
      _emitSignal.unlock();
    }
  }

  static void _onEntryPoint(ThreadInitialState initialState) async {
    final receivePort = ReceivePort();
    initialState.sendPort.send(receivePort.sendPort);
    
    final emitter = ThreadEventEmitter(receivePort, initialState.sendPort);
    initialState.eventHandler(emitter);

    emitter.onAny((event) {
      final message = event.message;
      if (message is ThreadComputeRequest) {
        message.compute(event.topic, emitter);
      }
    });

    await emitter.untilEnd();
  }

  EventListener on<MessageType>(String topic, void Function(MessageType data) callback) => _threadEmitter.on(topic, callback);
  Future<MessageType> once<MessageType>(String topic, void Function(MessageType data) callback) => _threadEmitter.once(topic, callback);
  
  void emit<MessageType>(String topic, MessageType data) async {
    if (keepEmitsWhileNotRunning) await _emitSignal.wait();
    emitter?.emit(topic, data);
  }

  Future<ReturnType> compute<ReturnType>(ReturnType Function() callback) {
    return computeWith(null, (void data) => callback());
  }

  Future<ReturnType> computeWith<EntryType, ReturnType>(EntryType data, ReturnType Function(EntryType data) callback) async {
    final uuid = _uuid.v4();
    final result = Completer<ReturnType>();
    once(uuid, (ReturnType data) => result.complete(data));
    emit(uuid, ThreadComputeRequest(data, callback));
    return result.future;
  }

  void stop({ int priority = Isolate.immediate }) {
    isolate?.kill(priority: priority);
    isolate = null;
    _emitSignal.lock();
  }
}