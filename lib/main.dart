import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'task_card.dart';
import 'package:windows_video_creator/video_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => VideoProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ColdBrew Cut',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoProvider>();
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ColdBrew Cut',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildControls(context, provider, messenger),
            const SizedBox(height: 10),

            _buildTaskListHeader(),
            const Divider(),
            Expanded(
              child: provider.tasks.isEmpty
                  ? const Center(child: Text('Chưa có video nào được thêm.'))
                  : _buildTaskList(provider),
            ),
            const SizedBox(height: 10),
            _buildRenderSection(context, provider, messenger),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, VideoProvider provider, ScaffoldMessengerState messenger) {
    return Row(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.video_call),
          label: const Text('Thêm Video'),
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.video,
              allowMultiple: true,
            );
            if (result != null) {
              for (var file in result.files) {
                if (file.path != null) {
                  provider.addTask(file.path!);
                }
              }
            }
          },
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.folder_open),
          label: const Text('Chọn thư mục output'),
          onPressed: () async {
            final result = await FilePicker.platform.getDirectoryPath();
            if (result != null) {
              provider.setOutputDirectory(result);
              messenger.showSnackBar(
                SnackBar(content: Text('Thư mục đầu ra: $result')),
              );
            }
          },
        ),
        const Spacer(),
        if (provider.outputDirectory != null)
          Text('Đầu ra: ${provider.outputDirectory}', style: const TextStyle(fontStyle: FontStyle.italic)),
      ],
    );
  }



  Widget _buildTaskListHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Video', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Độ dài (giây)', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text('Âm thanh', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Tên Output', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Tiến độ', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 80, child: Center(child: Text('Hành động', style: TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildTaskList(VideoProvider provider) {
    return ListView.builder(
      itemCount: provider.tasks.length,
      itemBuilder: (context, index) {
        final task = provider.tasks[index];
        return TaskCard(task: task, provider: provider);
      },
    );
  }

  Widget _buildRenderSection(BuildContext context, VideoProvider provider, ScaffoldMessengerState messenger) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          icon: provider.isRendering ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
          label: Text(provider.isRendering ? 'Đang Render...' : 'Bắt đầu Render'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
          onPressed: provider.isRendering || provider.tasks.isEmpty
              ? null
              : () {
                  if (provider.outputDirectory == null) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Vui lòng chọn thư mục đầu ra trước khi render.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  provider.startRendering();
                },
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
            height: 100,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(provider.logMessages.join('\n'), style: const TextStyle(fontFamily: 'monospace')),
            ),
          ),
        ),
      ],
    );
  }
}
