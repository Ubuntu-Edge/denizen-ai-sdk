import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/model_download_service.dart';

class CustomModelPickerDialog extends StatefulWidget {
  final Function() onModelSelected;

  const CustomModelPickerDialog({
    super.key,
    required this.onModelSelected,
  });

  @override
  State<CustomModelPickerDialog> createState() =>
      _CustomModelPickerDialogState();
}

class _CustomModelPickerDialogState extends State<CustomModelPickerDialog> {
  final _downloadService = ModelDownloadService.instance;
  bool _isLoading = false;
  String? _selectedModelPath;
  String? _modelInfo;

  @override
  void initState() {
    super.initState();
    _loadCurrentModel();
  }

  Future<void> _loadCurrentModel() async {
    final customPath = await _downloadService.getCustomModelPath();
    if (mounted && customPath != null) {
      setState(() {
        _selectedModelPath = customPath;
        _modelInfo = _getModelInfo(customPath);
      });
    }
  }

  String _getModelInfo(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return '⚠️ File not found';
      }
      final sizeMB = file.lengthSync() / (1024 * 1024);
      final fileName = filePath.split('/').last;
      return '$fileName\n${sizeMB.toStringAsFixed(1)} MB';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<void> _pickModelFile() async {
    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select GGUF Model File',
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;

        // Validate it's a GGUF file
        if (!filePath.toLowerCase().endsWith('.gguf')) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Please select a .gguf file'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        final success = await _downloadService.setCustomModelPath(filePath);

        if (mounted) {
          setState(() {
            _isLoading = false;
            if (success) {
              _selectedModelPath = filePath;
              _modelInfo = _getModelInfo(filePath);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Model selected successfully'),
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '❌ Failed to set model. Make sure it\'s a GGUF file.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _clearModel() async {
    await _downloadService.clearCustomModelPath();
    if (mounted) {
      setState(() {
        _selectedModelPath = null;
        _modelInfo = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Custom model cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.model_training, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Load Custom GGUF Model',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select a GGUF model file from your device',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_selectedModelPath != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Model Selected',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _modelInfo ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickModelFile,
                    icon: const Icon(Icons.folder_open),
                    label: Text(_selectedModelPath != null
                        ? 'Change Model'
                        : 'Browse Files'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_selectedModelPath != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _clearModel,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedModelPath != null && !_isLoading
                      ? () {
                          widget.onModelSelected();
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Use This Model'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
