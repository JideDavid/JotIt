import 'dart:async';

enum NoteAiStage { checkingSession, generating, checkingProposal, correcting }

class NoteAiCancelled implements Exception {
  const NoteAiCancelled();
}

/// Stops local waiting and prevents corrections after cancellation. Requests
/// already sent to the provider may still finish remotely.
class NoteAiCancellation {
  final _stopped = Completer<void>();
  bool get isCancelled => _stopped.isCompleted;
  void cancel() {
    if (!isCancelled) _stopped.complete();
  }

  void check() {
    if (isCancelled) throw const NoteAiCancelled();
  }

  Future<T> wait<T>(Future<T> operation) => Future.any([
    operation,
    _stopped.future.then<T>((_) => throw const NoteAiCancelled()),
  ]);
}
