import '../../../../core/error/failures.dart';

sealed class DownloadState {
  const DownloadState();
}

class Progressing extends DownloadState {
  final double progress;
  const Progressing(this.progress);
}

class Completed extends DownloadState {
  const Completed();
}

class Failed extends DownloadState {
  final Failure failure;
  const Failed(this.failure);
}
