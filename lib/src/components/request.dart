part of '../thread.dart';

typedef ComputeCallback<EntryT, ReturnT> = FutureOr<ReturnT> Function(EntryT data);
typedef EmptyComputeCallback<ReturnT> = FutureOr<ReturnT> Function();

class ThreadComputeRequest<EntryT, ReturnT> extends Event<EntryT> {
  ThreadComputeRequest(super.type, super.data, this.computation);

  final ComputeCallback<EntryT, ReturnT> computation;
  Future<void> compute(String topic, EventEmitter events) async => events.emit(topic, await computation(data));
}
