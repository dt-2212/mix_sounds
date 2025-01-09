import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;

void main() {
  runApp(AudioMixerApp());
}

class AudioMixerApp extends StatelessWidget {
  const AudioMixerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Mixer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AudioMixerHomePage(),
    );
  }
}

class AudioMixerHomePage extends StatefulWidget {
  const AudioMixerHomePage({super.key});

  @override
  _AudioMixerHomePageState createState() => _AudioMixerHomePageState();
}

class _AudioMixerHomePageState extends State<AudioMixerHomePage> {
  final List<File> _audioFiles = [];
  File? _mixedAudioFile;
  bool _isMixing = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final int _maxFiles = 5;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
  }

  Future<void> _pickAudio() async {
    if (_audioFiles.length >= _maxFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bạn đã chọn đủ $_maxFiles tệp âm thanh.')),
      );
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      File selectedFile = File(result.files.single.path!);
      setState(() {
        _audioFiles.add(selectedFile);
      });
    } else {}
  }

  Future<void> _pickAudioFromAssets() async {
    List<String> assetAudioPaths = [
      'assets/audio/1.mp3',
      'assets/audio/2.mp3',
      'assets/audio/3.mp3',
      'assets/audio/4.mp3',
      'assets/audio/5.mp3',
    ];

    String? selectedAsset = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('Chọn âm thanh từ Assets'),
          children: assetAudioPaths.map((String assetPath) {
            String fileName = assetPath.split('/').last;
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, assetPath);
              },
              child: Text(fileName),
            );
          }).toList(),
        );
      },
    );

    if (selectedAsset != null) {
      if (_audioFiles.length >= _maxFiles) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bạn đã chọn đủ $_maxFiles tệp âm thanh.')),
        );
        return;
      }

      // Sao chép tệp từ assets vào thư mục tạm thời
      File copiedFile = await _copyAssetToFile(selectedAsset);

      setState(() {
        _audioFiles.add(copiedFile);
      });
    }
  }

  Future<File> _copyAssetToFile(String assetPath) async {
    ByteData byteData = await rootBundle.load(assetPath);
    Directory tempDir = await getTemporaryDirectory();
    String fileName = assetPath.split('/').last;
    String tempPath = '${tempDir.path}/$fileName';
    File file = File(tempPath);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _removeAudio(int index) async {
    setState(() {
      _audioFiles.removeAt(index);
    });
  }

  Future<void> _deleteFileIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _mixAudio() async {
    if (_audioFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn ít nhất một tệp âm thanh.')),
      );
      return;
    }

    setState(() {
      _isMixing = true;
    });

    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String outputPath = '${appDir.path}/mixed_audio_$timestamp.mp3';

      await _deleteFileIfExists(outputPath);

      String inputs = '';
      String amixFilter = 'amix=inputs=${_audioFiles.length}:duration=longest';
      // có thể thay longest bằng các thông số khác để điều chỉnh file output

      for (int i = 0; i < _audioFiles.length; i++) {
        inputs += '-i "${_audioFiles[i].path}" ';
      }

      String command = '$inputs-filter_complex "$amixFilter" "$outputPath"';

      await FFmpegKit.executeAsync(command, (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          setState(() {
            _mixedAudioFile = File(outputPath);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Trộn âm thanh thành công!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi trộn âm thanh.')),
          );
        }
        setState(() {
          _isMixing = false;
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xảy ra lỗi: $e')),
      );
      setState(() {
        _isMixing = false;
      });
    }
  }

  Future<void> _playMixedAudio() async {
    if (_mixedAudioFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chưa có âm thanh được trộn.')),
      );
      return;
    }

    await _audioPlayer.play(DeviceFileSource(_mixedAudioFile!.path));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildAudioList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _audioFiles.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Icon(Icons.audiotrack),
          title: Text(_audioFiles[index].path.split('/').last),
          trailing: IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeAudio(index),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Audio Mixer'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(child: _buildAudioList()),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickAudio,
                    icon: Icon(Icons.add),
                    label: Text('Thêm từ File'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickAudioFromAssets,
                    icon: Icon(Icons.library_music),
                    label: Text('Thêm từ Assets'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isMixing ? null : _mixAudio,
                child: _isMixing
                    ? CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : Text('Trộn âm thanh'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _playMixedAudio,
                child: Text('Phát âm thanh trộn'),
              ),
              SizedBox(height: 20),
              _mixedAudioFile != null ? Text('Đường dẫn: ${_mixedAudioFile!.path}') : Container(),
            ],
          ),
        ));
  }
}
