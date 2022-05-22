library thread;

import 'dart:async';
import 'dart:isolate';

import 'package:events_emitter/events_emitter.dart';
import 'package:async_signal/async_signal.dart';
import 'package:uuid/uuid.dart';

part 'thread_event_emitter.dart';
part 'schemas.dart';

/// # Isolate Thread
/// 
/// A simple Isolated Thread wrapped with a type-safe Event Emitter for easier asynchronous communication.
/// 
/// Setup events for the thread to reply to, or compute tasks individually.
/// 
/// ## Usage
/// 
/// ```dart
/// final thread = Thread((emitter) {
///     emitter.on('compute', (String data) async {
///         await Future.delayed(const Duration(seconds: 1));
///         emitter.emit('result', '[Computed] $data');
///     });
/// });
/// 
/// thread.on('result', (String data) => print(data));
/// 
/// thread.emit('compute', 'Hello world!');
/// thread.emit('compute', 'Wow!');
/// 
/// print(await thread.compute(() => 'Hello world!'));
/// print(await thread.computeWith(123, (int data) => 'Wow $data'));
/// ```
class Thread {
  final _threadEmitter = EventEmitter();
  Isolate? isolate;
  /// Preserve events if the thread is not running with [keepEmitsWhileNotRunning]
  final bool keepEmitsWhileNotRunning;
  final _uuid = const Uuid();

  final ReceivePort receivePort = ReceivePort();
  ThreadEventEmitter? emitter;

  final void Function(EventEmitter emitter)? eventHandler;

  final _emitSignal = AsyncSignal(locked: true);
  bool get running => !_emitSignal.locked;

  /// # Isolate Thread
  /// 
  /// A simple Isolated Thread wrapped with a type-safe Event Emitter for easier asynchronous communication.
  /// 
  /// Setup events for the thread to reply to, or compute tasks individually.
  /// 
  /// * Start the thread automatically or manually with [start]
  /// * Preserve events if the thread is not running with [keepEmitsWhileNotRunning]
  Thread(this.eventHandler, { bool start = true, this.keepEmitsWhileNotRunning = true }) {
    if (start) this.start();
  }

  /// Create a thread with no initial function
  Thread.empty({ bool start = true, this.keepEmitsWhileNotRunning = true }) : eventHandler = null {
    if (start) this.start();
  }
  
  /// Starts the thread.
  /// 
  /// If the thread is already running, this is ignored.
  Future<void> start() async {
    if (running) return;

    isolate = await Isolate.spawn(_onEntryPoint, ThreadInitialState(receivePort.sendPort, eventHandler));

    final receiveStream = receivePort.asBroadcastStream();   
    final sendPort = await receiveStream.first;
    if (sendPort is SendPort) {
      emitter = ThreadEventEmitter(receivePort, sendPort, receiveStream: receiveStream);
      emitter!.onAny((dynamic event) => _threadEmitter.emitEvent(event));
      _emitSignal.unlock();
    }
  }

  static void _onEntryPoint(ThreadInitialState initialState) async {
    final receivePort = ReceivePort();
    initialState.sendPort.send(receivePort.sendPort);
    
    final emitter = ThreadEventEmitter(receivePort, initialState.sendPort);
    if (initialState.eventHandler != null) initialState.eventHandler!(emitter);
    emitter.onAny<ThreadComputeRequest>((event) => event.message.compute(event.topic, emitter));

    await emitter.untilEnd();
  }

  /// Listen to any event emitted by the thread.
  StreamSubscription<Event<MessageType>> onAny<MessageType>(void Function(Event<MessageType> event) callback) => _threadEmitter.onAny<MessageType>(callback);  

  /// Listen to events from the thread.
  EventListener<MessageType> on<MessageType>(String topic, void Function(MessageType data) callback) => _threadEmitter.on<MessageType>(topic, callback);

  /// Listen to the next event from the thread once.
  Future<MessageType> once<MessageType>(String topic, void Function(MessageType data) callback) => _threadEmitter.once<MessageType>(topic, callback);
  
  /// Emit an event to the thread.
  void emit<MessageType>(String topic, MessageType data) async {
    if (keepEmitsWhileNotRunning) await _emitSignal.wait();
    emitter?.emit(topic, data);
  }

  /// Sends a task to the thread to be computed.
  /// 
  /// Reply with the result by returning, can be `async`.
  Future<ReturnType> compute<ReturnType>(ReturnType Function() callback) {
    return computeWith(null, (void data) => callback());
  }

  /// Sends the task and data to the thread to be computed.
  /// 
  /// Reply with the result by returning, can be `async`.
  Future<ReturnType> computeWith<EntryType, ReturnType>(EntryType data, ReturnType Function(EntryType data) callback) async {
    final uuid = _uuid.v4();
    final result = Completer<ReturnType>();
    once(uuid, (ReturnType data) => result.complete(data));
    emit(uuid, ThreadComputeRequest(data, callback));
    return result.future;
  }

  /// Stops the thread as soon as it can.
  /// 
  /// The same can be achieved by using `emitter.emit('end', true)`.
  /// 
  /// After this the thread can be started again, it will start as a new thread but on this same object.
  void stop({ int priority = Isolate.immediate }) {
    isolate?.kill(priority: priority);
    isolate = null;
    _emitSignal.lock();
  }
}