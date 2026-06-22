import 'dart:async';
import '../../features/quran_reader/data/datasources/quran_local_data_source.dart';
import '../../features/quran_reader/data/datasources/quran_remote_data_source.dart';
import '../../features/quran_reader/domain/entities/download_state.dart';
import '../constants/quran_constants.dart';
import '../error/failures.dart';

class TafsirDownloadService {
  final QuranLocalDataSource localDataSource;
  final QuranRemoteDataSource remoteDataSource;

  TafsirDownloadService({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  Stream<DownloadState> downloadTafsir(int resourceId) {
    final controller = StreamController<DownloadState>();
    bool hasError = false;

    Future<int> startChapterForResume() async {
      int maxChapter = await localDataSource.getMaxDownloadedChapter(resourceId);
      return maxChapter > QuranConstants.tafsirDownloadConcurrency 
          ? maxChapter - QuranConstants.tafsirDownloadConcurrency 
          : 1;
    }

    Future<void> emitProgress() async {
      int completedVerses = await localDataSource.getDownloadedVerseCount(resourceId);
      double progress = completedVerses / QuranConstants.totalVerses;
      if (progress > 1.0) progress = 1.0;
      if (!controller.isClosed && !hasError) {
        controller.add(Progressing(progress));
      }
    }

    Future<void> downloadChapterWithRetry(int chapter) async {
      int page = 1;
      bool hasNext = true;

      while (hasNext) {
        if (hasError) return;

        int retries = 0;
        Map<String, dynamic>? response;

        while (retries <= QuranConstants.tafsirMaxRetries) {
          try {
            response = await remoteDataSource.getTafsirByChapter(
              resourceId,
              chapter,
              page: page,
              perPage: QuranConstants.tafsirPerPage,
            );
            break;
          } catch (e) {
            retries++;
            if (retries > QuranConstants.tafsirMaxRetries) {
              throw Failure.fromException(e);
            }
            await Future.delayed(Duration(seconds: retries * 2));
          }
        }

        if (hasError || response == null) return;

        final List tafsirs = response['tafsirs'] ?? [];
        if (tafsirs.isNotEmpty) {
          final rows = tafsirs.map((t) => <String, dynamic>{
            'verse_key': t['verse_key'],
            'resource_id': resourceId,
            'text': t['text'],
          }).toList();

          await localDataSource.insertTafsirs(rows);
          await emitProgress();
        }

        final pagination = response['pagination'];
        hasNext = pagination != null && pagination['next_page'] != null;
        page++;
      }
    }

    Future<void> runWorker(int workerId, int safeStartChapter) async {
      for (int i = workerId; i <= QuranConstants.totalSurahs; i += QuranConstants.tafsirDownloadConcurrency) {
        if (hasError) return;
        if (i < safeStartChapter) continue;

        try {
          await downloadChapterWithRetry(i);
        } catch (e) {
          if (!hasError) {
            hasError = true;
            if (!controller.isClosed) {
              controller.add(Failed(Failure.fromException(e)));
              controller.close();
            }
          }
          return;
        }
      }
    }

    () async {
      try {
        final safeStartChapter = await startChapterForResume();
        await emitProgress();

        final workers = List.generate(
          QuranConstants.tafsirDownloadConcurrency,
          (index) => runWorker(index + 1, safeStartChapter),
        );
        
        await Future.wait(workers);

        if (!hasError && !controller.isClosed) {
          await localDataSource.markTafsirAsCompleted(resourceId);
          controller.add(const Completed());
          controller.close();
        }
      } catch (e) {
        if (!hasError && !controller.isClosed) {
          hasError = true;
          controller.add(Failed(Failure.fromException(e)));
          controller.close();
        }
      }
    }();

    return controller.stream;
  }
}
