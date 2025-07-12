import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum FileConflictAction { Skip, Overwrite, KeepBoth }

enum RenderMode { loopToDuration, loopToAudio }

class VideoTask with ChangeNotifier {
  final String id;
  final String videoPath;
  String outputName;
  RenderMode _renderMode = RenderMode.loopToAudio;
  double targetDuration = 0.0;
  String? _audioPath;
  late TextEditingController outputNameController;
  late TextEditingController durationController;

  double progress = 0.0;
  String? outputPath;
  bool isCompleted = false;
  String _status = 'Pending';

  String get status => _status;
  RenderMode get renderMode => _renderMode;
  String? get audioPath => _audioPath;

  VideoTask({
    required this.videoPath,
  }) : id = const Uuid().v4(), outputName = p.basenameWithoutExtension(videoPath) {
    outputNameController = TextEditingController(text: outputName);
    durationController = TextEditingController(text: '');
  }

  void _setRenderMode(RenderMode mode) {
    if (_renderMode != mode) {
      _renderMode = mode;
      if (mode == RenderMode.loopToDuration) {
        _audioPath = null;
      } else {
        durationController.clear();
        targetDuration = 0.0;
      }
    }
  }

  void _setAudioPath(String path) {
    _audioPath = path;
    _setRenderMode(RenderMode.loopToAudio);
  }

  void updateStatus(String newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  void updateProgress(double newProgress) {
    progress = newProgress;
    notifyListeners();
  }

  void dispose() {
    outputNameController.dispose();
    durationController.dispose();
  }
}

class VideoProvider with ChangeNotifier {
  final _tasks = <VideoTask>[];
  String? _outputDirectory;
  bool _isRendering = false;
  final _logMessages = <String>[];

  List<VideoTask> get tasks => _tasks;
  String? get outputDirectory => _outputDirectory;
  bool get isRendering => _isRendering;
  List<String> get logMessages => _logMessages;

  Future<void> revealInFinder(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      }
    } catch (e) {
      addToLog('Không thể mở tệp: $e');
    }
  }

  void addTask(String videoPath) {
    final task = VideoTask(videoPath: videoPath);
    _tasks.add(task);
    notifyListeners();
  }

  void removeTask(String taskId) {
    final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex != -1) {
      _tasks[taskIndex].dispose();
      _tasks.removeAt(taskIndex);
      notifyListeners();
    }
  }

  void updateTaskDuration(String taskId, String value) {
    final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex != -1) {
      final task = _tasks[taskIndex];
      task.targetDuration = double.tryParse(value) ?? 0.0;
      if (value.isNotEmpty) {
        task._setRenderMode(RenderMode.loopToDuration);
      } else if (task.audioPath == null) {
        // Revert to audio mode only if no audio is selected
      }
      notifyListeners();
    }
  }

  void updateTaskAudioPath(String taskId, String path) {
    final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex != -1) {
      _tasks[taskIndex]._setAudioPath(path);
      notifyListeners();
    }
  }

  void setOutputDirectory(String path) {
    _outputDirectory = path;
    notifyListeners();
  }

  void addToLog(String message) {
    _logMessages.add(message);
    notifyListeners();
  }

  void clearLog() {
    _logMessages.clear();
    notifyListeners();
  }

  Future<double> _getMediaDuration(String filePath, String ffprobePath) async {
    final arguments = ['-v', 'quiet', '-print_format', 'json', '-show_format', filePath];
    final result = await Process.run(ffprobePath, arguments);
    if (result.exitCode == 0) {
      try {
        final jsonData = jsonDecode(result.stdout);
        final durationString = jsonData['format']['duration'];
        return double.tryParse(durationString ?? '0.0') ?? 0.0;
      } catch (e) {
        throw Exception('Failed to parse ffprobe output: $e');
      }
    } else {
      throw Exception('FFprobe failed with exit code ${result.exitCode}: ${result.stderr}');
    }
  }

    Future<String> _getUniqueFilePath(String filePath) async {
    String directory = p.dirname(filePath);
    String filename = p.basenameWithoutExtension(filePath);
    String extension = p.extension(filePath);
    int counter = 1;

    String newFilePath = filePath;
    while (await File(newFilePath).exists()) {
      newFilePath = p.join(directory, '$filename ($counter)$extension');
      counter++;
    }
    return newFilePath;
  }

  Future<FileConflictAction?> _showConflictDialog(BuildContext context, String fileName) async {
    return showDialog<FileConflictAction>(
      context: context,
      barrierDismissible: false, // User must choose an action
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tệp đã tồn tại'),
          content: Text('Tệp "$fileName" đã có trong thư mục output. Bạn muốn làm gì?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Bỏ qua'),
              onPressed: () => Navigator.of(context).pop(FileConflictAction.Skip),
            ),
            TextButton(
              child: const Text('Ghi đè'),
              onPressed: () => Navigator.of(context).pop(FileConflictAction.Overwrite),
            ),
            TextButton(
              child: const Text('Giữ cả hai'),
              onPressed: () => Navigator.of(context).pop(FileConflictAction.KeepBoth),
            ),
          ],
        );
      },
    );
  }

  Future<void> startRendering(BuildContext context) async {
    if (_isRendering || _outputDirectory == null) return;

    _isRendering = true;
    clearLog();
    addToLog('Bắt đầu quá trình render...');
    notifyListeners();

    final exeDir = p.dirname(Platform.resolvedExecutable);
    final ffmpegPath = p.join(exeDir, 'data', 'flutter_assets', 'assets', 'ffmpeg.exe');
    final ffprobePath = p.join(exeDir, 'data', 'flutter_assets', 'assets', 'ffprobe.exe');

    for (var task in _tasks) {
      if (task.isCompleted) continue;

      task.updateStatus('Đang xử lý...');
      task.updateProgress(0.0);

      try {
        final videoDuration = await _getMediaDuration(task.videoPath, ffprobePath);
        if (videoDuration <= 0) {
          throw Exception('Không thể đọc thời lượng video cho ${task.outputName}.');
        }

        double effectiveTargetDuration;
        String outputPath = p.join(_outputDirectory!, '${task.outputName}.mp4');

        // Handle file conflicts
        if (await File(outputPath).exists()) {
          final action = await _showConflictDialog(context, p.basename(outputPath));

          if (action == null || action == FileConflictAction.Skip) {
            task.updateStatus('Đã bỏ qua');
            addToLog('Đã bỏ qua tác vụ ${task.outputName} do tệp đã tồn tại.');
            continue; // Skip to the next task
          } else if (action == FileConflictAction.KeepBoth) {
            outputPath = await _getUniqueFilePath(outputPath);
            addToLog('Tệp mới sẽ được lưu tại: $outputPath');
          } 
          // If Overwrite, do nothing, ffmpeg's -y flag will handle it.
        }

        task.outputPath = outputPath;

        if (task.renderMode == RenderMode.loopToAudio) {
          if (task.audioPath == null) {
            throw Exception('Vui lòng chọn tệp âm thanh cho tác vụ ${task.outputName}.');
          }
          effectiveTargetDuration = await _getMediaDuration(task.audioPath!, ffprobePath);
          if (effectiveTargetDuration <= 0) {
            throw Exception('Không thể đọc thời lượng âm thanh.');
          }
        } else {
          effectiveTargetDuration = task.targetDuration;
          if (effectiveTargetDuration <= 0) {
            throw Exception('Vui lòng nhập thời lượng lớn hơn 0 cho tác vụ ${task.outputName}.');
          }
        }

        final loopCount = (effectiveTargetDuration / videoDuration).ceil();
        final lastSegmentDuration = effectiveTargetDuration - (videoDuration * (loopCount - 1));

        var filterComplex = '';
        var concatInputs = '';
        for (var i = 1; i <= loopCount; i++) {
          final isLastSegment = (i == loopCount);
          final segmentDuration = isLastSegment ? lastSegmentDuration : videoDuration;
          if (i % 2 == 1) {
            filterComplex += '[0:v]trim=0:$segmentDuration,setpts=PTS-STARTPTS[v$i];';
          } else {
            filterComplex += '[0:v]reverse,setpts=PTS-STARTPTS,trim=0:$segmentDuration,setpts=PTS-STARTPTS[v$i];';
          }
          concatInputs += '[v$i]';
        }
        filterComplex += '$concatInputs concat=n=$loopCount:v=1:a=0[v];[v]scale=1080:1920[vout]';

        List<String> commandArgs;
        if (task.renderMode == RenderMode.loopToAudio) {
          commandArgs = [
            '-i', task.videoPath,
            '-i', task.audioPath!,
            '-filter_complex', filterComplex,
            '-map', '[vout]',
            '-map', '1:a',
            '-c:v', 'libx264',
            '-preset', 'ultrafast',
            '-c:a', 'aac',
            '-shortest',
            outputPath,
          ];
        } else {
          commandArgs = [
            '-i', task.videoPath,
            '-filter_complex', filterComplex,
            '-map', '[vout]',
            '-t', effectiveTargetDuration.toString(),
            '-c:v', 'libx264',
            '-preset', 'ultrafast',
            '-an',
            outputPath,
          ];
        }
        commandArgs.add('-y'); // Overwrite output file if it exists

        addToLog('Đang xử lý tác vụ: ${task.outputName}...');
        final result = await Process.run(ffmpegPath, commandArgs);

        if (result.exitCode == 0) {
          task.updateStatus('Hoàn thành');
          task.isCompleted = true;
          task.updateProgress(1.0);
          addToLog('Render thành công: ${task.outputPath}');
        } else {
          task.updateStatus('Thất bại');
          addToLog('Render thất bại cho ${task.outputName}. Log: ${result.stderr}');
        }
      } catch (e) {
        task.updateStatus('Lỗi');
        addToLog('Lỗi khi xử lý tác vụ ${task.outputName}: $e');
      }
    }

    _isRendering = false;
    addToLog('Tất cả các tác vụ đã được xử lý.');
    notifyListeners();
  }
}

