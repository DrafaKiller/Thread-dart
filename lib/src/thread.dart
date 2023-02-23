import 'dart:async';
import 'dart:isolate';

import 'package:async_signal/async_signal.dart';
import 'package:events_emitter/events_emitter.dart';
import 'package:thread/event_emitter.dart';
import 'package:uuid/uuid.dart';

part 'errors.dart';
part 'components/request.dart';
part 'components/state.dart';

const uuid = Uuid();

class Thread {
  Isolate? isolate;
  final EventHandler? _eventHandler;

  final _signal = AsyncSignal(locked: true);
  
  /// Event Emitter for the thread.
  /// 
  /// - Emitting will make it send to the thread.
  /// - Listening will make it listen to the events received from the thread.
  ThreadEventEmitter? events;
  
  /// List of listeners appended to the thread while it has not started.
  /// 
  /// When the thread starts, the listeners are automatically added to the Event Emitter.
  final _deadListeners = <EventListener>[];
  
  bool get alive => isolate != null;
  bool get initialized => alive && events != null;
  
  /// ## Thread
  /// 
  /// A simple Isolated Thread wrapped with a type-safe Event Emitter for easier asynchronous communication.
  /// 
  /// Setup events for the thread to reply, or compute tasks individually.
  /// 
  /// ### Features
  /// 
  /// - Simple thread setup, control and communication
  /// - Type-safe communication between threads
  /// - Setup thread callbacks, using thread events
  /// - Compute tasks individually
  /// 
  /// ### Example
  /// 
  /// ```dart
  /// import 'package:thread/thread.dart';
  /// 
  /// void main() async {
  ///   final thread = Thread((events) {
  ///     events.on('data', (String data) async {
  ///       await Future.delayed(const Duration(seconds: 1));
  ///       events.emit('result', '<Computed> $data');
  ///     });
  ///   });
  /// 
  ///   thread.on('result', (String data) => print(data));
  /// 
  ///   thread.emit('data', 'Hello world!');
  ///   thread.emit('data', 'Wow!');
  /// 
  ///   print(await thread.compute(() => 'Hello world!'));
  ///   print(await thread.computeWith(123, (int data) => 'Wow $data'));
  /// 
  ///   // [Output]
  ///   // Hello world!
  ///   // Wow 123
  /// 
  ///   // <Computed> Hello world!
  ///   // <Computed> Wow!
  /// }
  /// ```
  Thread(this._eventHandler, { bool start = true }) {
    if (start) this.start();
  }

  /// Create a thread with no initial function
  factory Thread.empty({ bool start = true }) => Thread(null, start: start);

  /* -= Control Methods =- */
  
  /// Starts the thread, essentially spawning a new isolate.
  /// 
  /// If the thread is already alive, this is ignored.
  Future<void> start() async {
    if (alive) return;
    final receivePort = ReceivePort();
    isolate = await Isolate.spawn(
      _entryPoint, 
      ThreadInitialState(receivePort.sendPort, _eventHandler),
      debugName: 'ThreadIsolate-${uuid.v4()}',
    );

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

  /// Stops the thread as soon as it cans, essentially killing the isolate.
  /// 
  /// The same can be achieved by using `emitter.emit('end', true)`, this makes so it's the thread ending itss process internally.
  /// 
  /// After this the thread can be started again, it will start as a new thread but on this same object.
  void stop({ int priority = Isolate.immediate }) {
    if (!alive) return;
    isolate?.kill(priority: priority);
    isolate = null;
    events?.off();
    events = null;
    _signal.lock();
  }

  /// Pauses the processing queue of the thread.
  /// This does not stop the current task.
  /// 
  /// Same as doing `thread.isolate.pause()`.
  void pause() => isolate?.pause(isolate?.pauseCapability);

  /// Resumes the processing queue of the thread.
  /// 
  /// Same as doing `thread.isolate.resume(...)`.
  void resume() => isolate?.resume(isolate!.pauseCapability!);

  /// Future that resolves when the thread is alive.
  /// 
  /// Used to wait for the thread to start.
  FutureOr<void> untilAlive() async {
    if (initialized) return;
    await _signal.wait();
  }

  /* -= Compute Methods =- */

  /// Sends a compute request to the thread, with a task be to executed in the thread.
  /// 
  /// The returned result will be sent back, this task can be asynchronous.
  Future<ReturnT> compute<ReturnT>(EmptyComputeCallback<ReturnT> computation) {
    return computeWith(null, (void data) => computation());
  }

  /// Sends a compute request with some data to the thread, with a task be to executed in the thread.
  /// 
  /// The **data** sent will be available in the computation function, must to be **thread-safe**.
  /// 
  /// The returned result will be sent back, this task can be asynchronous.
  Future<ReturnT> computeWith<EntryT, ReturnT>(EntryT data, ComputeCallback<EntryT, ReturnT> computation) async {
    final id = uuid.v4();
    final result = once(id, (ReturnT data) {});
    emit(id, ThreadComputeRequest(id, data, computation));
    return result;
  }

  /* -= Event Methods =- */

  /// Adds a callback, that will be executed when receiving the event from the thread.
  /// 
  /// This callback does not need any event type.
  /// 
  /// The data type of the event will be matched in order to call the callback.
  EventListener<T> onAny<T>(EventCallback<T> callback) {
    if (events != null) return events!.onAny(callback);

    final listener = EventListener<T>(null, callback);
    _deadListeners.add(listener);
    return listener;
  }

  /// Adds a callback, that will be executed when receiving the event from the thread.
  /// 
  /// The event type and data type of the event will be matched in order to call the callback. 
  EventListener<T> on<T>(String? type, EventCallback<T> callback) {
    if (events != null) return events!.on(type, callback);

    final listener = EventListener<T>(type, callback);
    _deadListeners.add(listener); 
    return listener;
  }


  /// Adds a callback, that will be executed when receiving the event from the thread.
  /// 
  /// The event type and data type of the event will be matched in order to call the callback. 
  /// 
  /// This callback will only be called once.
  Future<T> once<T>(String? type, EventCallback<T> callback) async {
    await _signal.wait();
    return events!.once(type, callback);
  }

  /// Emits an event to be sent to the thread.
  /// 
  /// If the thread is not alive, this will wait until it is.
  Future<void> emit<T>(String type, [ T? data ]) async {
    await untilAlive();
    events!.emit(type, data);
  }
  
  /// Emits an event to be sent to the thread.
  /// 
  /// If the thread is not alive, this will wait until it is.
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

  /// Creates a temporary thread to run `thread.compute()`, the computation function will be executed in the thread.
  /// 
  /// **Warning:**
  /// Careful when starting threads too quickly, starting a thread can be performance intensive.
  /// These methods should only be used when necessary, as in one time situation. Often is better to keep a single thread constantly open and idle.
  // ignore: non_constant_identifier_names
  static Future<ReturnT> Compute<ReturnT>(ReturnT Function() computation) async {
    final thread = Thread.empty();
    final result = await thread.compute(computation);
    thread.stop();
    return result;
  }

  /// Creates a temporary thread to run `thread.computeWith()`, the computation function will be executed in the thread.
  /// 
  /// **Warning:**
  /// Careful when starting threads too quickly, starting a thread can be performance intensive.
  /// These methods should only be used when necessary, as in one time situation. Often is better to keep a single thread constantly open and idle.
  // ignore: non_constant_identifier_names
  static Future<ReturnT> ComputeWith<EntryT, ReturnT>(EntryT data, ComputeCallback<EntryT, ReturnT> computation) async {
    final thread = Thread.empty();
    final result = await thread.computeWith(data, computation);
    thread.stop();
    return result;
  }
}
