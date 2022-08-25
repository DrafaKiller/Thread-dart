part of thread;

class InvalidThreadSendPortException implements Exception {
  @override
  String toString() => 'It was not possible to establish a connection with the thread, the $SendPort given by the thread is invalid';
}
