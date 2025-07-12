import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:open_file_plus/open_file_plus.dart';
import 'video_provider.dart';

class TaskCard extends StatelessWidget {
  final VideoTask task;
  final VideoProvider provider;

  const TaskCard({super.key, required this.task, required this.provider});

  @override
  @override
  Widget build(BuildContext context) {
    // Use a Consumer to listen for changes in VideoProvider, like output directory selection
    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        // Find the task in the provider's list to ensure we have the latest state
        final task = provider.tasks.firstWhere((t) => t.id == this.task.id, orElse: () => this.task);
        final isOutputSet = provider.outputDirectory != null;
        return _buildTaskRow(context, provider, task, isOutputSet);
      },
    );
  }

  Widget _buildTaskRow(BuildContext context, VideoProvider provider, VideoTask task, bool isOutputSet) {
    // This widget is designed to be a single row in a ListView, aligned with the headers in main.dart
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Column 1: Video Name
          Expanded(
            flex: 3,
            child: Text(p.basename(task.videoPath), overflow: TextOverflow.ellipsis),
          ),
          // Column 2: Duration Input
          Expanded(
            flex: 2,
            child: _buildDurationInput(isOutputSet),
          ),
          // Column 3: Audio Input
          Expanded(
            flex: 3,
            child: _buildAudioInput(context, isOutputSet),
          ),
          // Column 4: Output Name
          Expanded(
            flex: 3, // Adjusted flex for better layout
            child: _buildOutputNameInput(isOutputSet),
          ),
          // Column 5: Progress Indicator
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildProgressIndicator(),
            ),
          ),
          // Column 6: Actions
          SizedBox(
            width: 100, // Increased width to fit two icons
            child: Center(
              child: task.isCompleted && task.outputPath != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.folder_open, color: Colors.blueAccent),
                          onPressed: () => provider.revealInFinder(task.outputPath!),
                          tooltip: 'Mở thư mục chứa file',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => provider.removeTask(task.id),
                          tooltip: 'Xóa tác vụ',
                        ),
                      ],
                    )
                  : IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => provider.removeTask(task.id),
                      tooltip: 'Xóa tác vụ',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputNameInput(bool isEnabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: TextField(
        controller: task.outputNameController,
        enabled: isEnabled,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          filled: !isEnabled,
          fillColor: Colors.grey.withOpacity(0.1),
        ),
        onChanged: (value) => task.outputName = value,
      ),
    );
  }

  Widget _buildDurationInput(bool isEnabled) {
    // Also check if the global output directory is set
    final isDurationEnabled = isEnabled && task.audioPath == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: TextField(
        controller: task.durationController,
        keyboardType: TextInputType.number,
        enabled: isDurationEnabled,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          filled: !isDurationEnabled,
          fillColor: Colors.grey.withOpacity(0.1),
        ),
        onChanged: (value) => provider.updateTaskDuration(task.id, value),
      ),
    );
  }

  Widget _buildAudioInput(BuildContext context, bool isEnabled) {
    // Also check if the global output directory is set
    final isAudioEnabled = isEnabled && task.durationController.text.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.audiotrack, size: 16),
        label: Text(
          task.audioPath != null ? p.basename(task.audioPath!) : 'Chọn file...',
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          textStyle: const TextStyle(fontSize: 12),
          backgroundColor: isAudioEnabled ? null : Colors.grey.withOpacity(0.2),
          foregroundColor: isAudioEnabled ? null : Colors.grey.withOpacity(0.5),
        ),
        onPressed: isAudioEnabled ? () async {
          final result = await FilePicker.platform.pickFiles(type: FileType.audio);
          if (result != null && result.files.single.path != null) {
            provider.updateTaskAudioPath(task.id, result.files.single.path!);
          }
        } : null,
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${(task.progress * 100).toStringAsFixed(0)}%'),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: task.progress,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
