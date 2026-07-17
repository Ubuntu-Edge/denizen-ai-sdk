import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/offline_model.dart';
import '../models/default_offline_models.dart';
import '../providers/offline_model_provider.dart';
import '../services/model_download_service.dart';
// NOTE: AppMigrationService is app-specific. Replace with your own reset logic.
// import '../../services/app_migration_service.dart';

/// Screen for downloading offline AI models
/// Shows available models, storage requirements, and download progress
class OfflineModelDownloadScreen extends StatefulWidget {
  const OfflineModelDownloadScreen({super.key});

  @override
  State<OfflineModelDownloadScreen> createState() =>
      _OfflineModelDownloadScreenState();
}

class _OfflineModelDownloadScreenState
    extends State<OfflineModelDownloadScreen> {
  final ModelDownloadService _downloadService = ModelDownloadService.instance;
  final Map<String, StreamSubscription<ModelDownloadProgress>>
      _downloadSubscriptions = {};
  final Map<String, ModelDownloadProgress> _downloadProgress = {};

  int _availableStorageGB = 0;
  int _usedStorageMB = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
    // Refresh model download statuses when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OfflineModelProvider>();
      provider.refreshDownloadStatuses();
      _reconnectToActiveDownloads();
    });
  }

  @override
  void dispose() {
    for (final subscription in _downloadSubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _loadStorageInfo() async {
    final availableBytes = await _downloadService.getAvailableStorageBytes();
    final usedBytes = await _downloadService.getModelsDirectorySize();

    setState(() {
      _availableStorageGB = (availableBytes / (1024 * 1024 * 1024)).round();
      _usedStorageMB = (usedBytes / (1024 * 1024)).round();
      _isLoading = false;
    });
  }

  /// Reconnect to any active downloads that are still in progress
  void _reconnectToActiveDownloads() {
    final provider = context.read<OfflineModelProvider>();

    // Check each model for active downloads
    for (final model in provider.models) {
      if (_downloadService.isDownloading(model.id)) {
        debugPrint('🔄 Reconnecting to download: ${model.name}');

        // Subscribe to the existing download stream
        final subscription = _downloadService
            .downloadModel(
          url: model.downloadUrl ?? '',
          modelId: model.id,
          fileName: model.filename ?? '${model.name}.gguf',
          author: model.author,
          useCompression: true,
        )
            .listen(
          (progress) {
            setState(() {
              _downloadProgress[model.id] = progress;
            });

            if (progress.stage == ModelDownloadStage.completed &&
                progress.localPath != null) {
              provider.markModelAsDownloaded(model.id, progress.localPath!);
              _downloadSubscriptions[model.id]?.cancel();
              _downloadSubscriptions.remove(model.id);
              _loadStorageInfo();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${model.name} downloaded successfully!'),
                    backgroundColor: Colors.green,
                    action: SnackBarAction(
                      label: 'Use Now',
                      textColor: Colors.white,
                      onPressed: () {
                        provider.setActiveModel(model);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                );
              }
            } else if (progress.stage == ModelDownloadStage.failed) {
              _downloadSubscriptions[model.id]?.cancel();
              _downloadSubscriptions.remove(model.id);
              setState(() {
                _downloadProgress.remove(model.id);
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Download failed: ${progress.error}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          onError: (error) {
            setState(() {
              _downloadProgress.remove(model.id);
            });
            _downloadSubscriptions[model.id]?.cancel();
            _downloadSubscriptions.remove(model.id);
          },
        );

        _downloadSubscriptions[model.id] = subscription;
      }
    }
  }

  Future<void> _downloadModel(OfflineModel model) async {
    // Check if already downloaded
    if (model.isDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${model.name} is already downloaded'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Use Now',
            textColor: Colors.white,
            onPressed: () {
              final provider = context.read<OfflineModelProvider>();
              provider.setActiveModel(model);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Model activated for offline use'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    if (_downloadService.isDownloading(model.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download already in progress')),
      );
      return;
    }

    // Check storage
    final requiredBytes = (model.sizeGB * 1024 * 1024 * 1024).toInt();
    final hasStorage = await _downloadService.hasEnoughStorage(requiredBytes);

    if (!hasStorage) {
      if (mounted) {
        _showStorageWarning(model);
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showDownloadConfirmation(model);
    if (!confirmed) return;

    // Start download
    final subscription = _downloadService
        .downloadModel(
      url: model.downloadUrl ?? '',
      modelId: model.id,
      fileName: model.filename ?? '${model.name}.gguf',
      author: model.author,
      useCompression: true,
    )
        .listen(
      (progress) {
        setState(() {
          _downloadProgress[model.id] = progress;
        });

        if (progress.stage == ModelDownloadStage.completed &&
            progress.localPath != null) {
          // Mark model as downloaded in provider
          final provider = context.read<OfflineModelProvider>();
          provider.markModelAsDownloaded(model.id, progress.localPath!);

          _downloadSubscriptions[model.id]?.cancel();
          _downloadSubscriptions.remove(model.id);

          _loadStorageInfo(); // Refresh storage info

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${model.name} downloaded successfully!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Use Now',
                textColor: Colors.white,
                onPressed: () {
                  provider.setActiveModel(model);
                  Navigator.pop(context);
                },
              ),
            ),
          );
        } else if (progress.stage == ModelDownloadStage.failed) {
          _downloadSubscriptions[model.id]?.cancel();
          _downloadSubscriptions.remove(model.id);

          // Clear progress state so download button shows again
          setState(() {
            _downloadProgress.remove(model.id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: ${progress.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onError: (error) {
        setState(() {
          _downloadProgress.remove(model.id);
        });
        _downloadSubscriptions[model.id]?.cancel();
        _downloadSubscriptions.remove(model.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );

    _downloadSubscriptions[model.id] = subscription;
  }

  Future<bool> _showDownloadConfirmation(OfflineModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download ${model.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Size: ${model.sizeGB.toStringAsFixed(2)} GB'),
            const SizedBox(height: 8),
            Text('Quantization: ${model.quantization ?? "Standard"}'),
            const SizedBox(height: 8),
            const Text(
              'This may take 5-10 minutes depending on your connection.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              '💡 Tip: Use WiFi to avoid data charges',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showStorageWarning(OfflineModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insufficient Storage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${model.name} requires ${model.sizeGB.toStringAsFixed(2)} GB'),
            const SizedBox(height: 8),
            Text('Available: $_availableStorageGB GB'),
            const SizedBox(height: 16),
            const Text(
              'Please free up space and try again.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelDownload(String modelId) async {
    // Cancel download service
    await _downloadService.cancelDownload(modelId);

    // Cancel subscription
    _downloadSubscriptions[modelId]?.cancel();
    _downloadSubscriptions.remove(modelId);

    // Remove progress state to show download button again
    setState(() {
      _downloadProgress.remove(modelId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download cancelled and partial files deleted'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _deleteModel(OfflineModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model?'),
        content: Text(
          'Are you sure you want to delete ${model.name}? '
          'You will need to download it again to use offline mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && model.localPath != null) {
      final success = await _downloadService.deleteModel(model.localPath!);
      if (success) {
        final provider = context.read<OfflineModelProvider>();
        await provider.updateModel(model.copyWith(
          isDownloaded: false,
          localPath: null,
          downloadProgress: 0,
        ));
        await _loadStorageInfo();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${model.name} deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  Future<void> _useModel(OfflineModel model) async {
    final provider = context.read<OfflineModelProvider>();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading model...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await provider.setActiveModel(model);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.name} is now active for offline use'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Got it',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Unload the active model from memory without deleting it
  Future<void> _unloadModel(OfflineModelProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unload Model?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will unload the model from memory to free up resources.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
                'The model will remain downloaded and you can load it again anytime.'),
            SizedBox(height: 12),
            Text(
              '💡 Use Online mode when the model is unloaded',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Unload'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Unloading model...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        await provider.clearActiveModel();

        if (mounted) {
          Navigator.pop(context); // Close loading dialog

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Model unloaded. You can use Online mode or load a model again.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unload model: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showResetSettingsDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reset App Settings?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will clear all app settings and preferences to fix any bugs from previous versions.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('What WILL be reset:'),
            Text('• AI mode preference (online/offline)'),
            Text('• App settings and cache'),
            Text('• Any stored preferences'),
            SizedBox(height: 16),
            Text('What will be KEPT:'),
            Text('✅ Downloaded models'),
            Text('✅ Your login'),
            Text('✅ Active model selection'),
            SizedBox(height: 16),
            Text(
              'The app will restart after reset.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Reset Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performResetSettings();
    }
  }

  Future<void> _performResetSettings() async {
    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Resetting settings...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // TODO: Replace with your own app reset logic
      // Original: await AppMigrationService.clearAllAppData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        // Show success and restart instruction
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Settings Reset'),
              ],
            ),
            content: const Text(
              'App settings have been reset successfully.\n\n'
              'Please close and reopen the app for changes to take effect.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  // Close all dialogs and return to previous screen
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download AI Models'),
        elevation: 0,
        actions: [
          // Reset Settings button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset App Settings',
            onPressed: () => _showResetSettingsDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStorageInfo(),
                Expanded(
                  child: _buildModelList(),
                ),
              ],
            ),
    );
  }

  Widget _buildStorageInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Storage Available',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '$_availableStorageGB GB',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Models Downloaded',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '$_usedStorageMB MB',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '📱 Models are stored on your device for offline use',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList() {
    return Consumer<OfflineModelProvider>(
      builder: (context, provider, child) {
        final models = DefaultOfflineModels.getMedicalModels();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: models.length,
          itemBuilder: (context, index) {
            final model = models[index];
            final providerModel = provider.models.firstWhere(
              (m) => m.id == model.id,
              orElse: () => model,
            );

            return _buildModelCard(providerModel);
          },
        );
      },
    );
  }

  Widget _buildModelCard(OfflineModel model) {
    final progress = _downloadProgress[model.id];
    final isDownloading = _downloadService.isDownloading(model.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        model.description ?? 'No description available',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (model.tags.contains('recommended'))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  Icons.storage,
                  model.isDownloaded && model.localPath != null
                      ? _getActualFileSize(model.localPath!)
                      : '${model.sizeGB.toStringAsFixed(1)} GB',
                ),
                const SizedBox(width: 8),
                if (model.quantization != null)
                  _buildInfoChip(
                    Icons.compress,
                    model.quantization!,
                  ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.speed,
                  '${model.contextSize ~/ 1000}k context',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isDownloading && progress != null)
              _buildDownloadProgress(model, progress)
            else if (model.isDownloaded)
              _buildDownloadedActions(model)
            else
              _buildDownloadButton(model),
          ],
        ),
      ),
    );
  }

  String _getActualFileSize(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        final gb = bytes / (1024 * 1024 * 1024);
        if (gb >= 1.0) {
          return '${gb.toStringAsFixed(1)} GB';
        } else {
          final mb = bytes / (1024 * 1024);
          return '${mb.toStringAsFixed(0)} MB';
        }
      }
    } catch (e) {
      debugPrint('Error getting file size: $e');
    }
    return 'Unknown size';
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(OfflineModel model) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _downloadModel(model),
        icon: const Icon(Icons.download),
        label: const Text('Download'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDownloadProgress(
      OfflineModel model, ModelDownloadProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                progress.progressText,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (progress.speedText != null)
              Text(
                progress.speedText!,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.progress / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress.stage == ModelDownloadStage.extracting
                ? Colors.orange
                : Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _cancelDownload(model.id),
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadedActions(OfflineModel model) {
    return Consumer<OfflineModelProvider>(
      builder: (context, provider, child) {
        final isActive = provider.activeModel?.id == model.id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.check_circle_outline,
                  color: isActive ? Colors.blue : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'Active Model' : 'Downloaded',
                  style: TextStyle(
                    color: isActive ? Colors.blue : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _deleteModel(model),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isActive)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _useModel(model),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('Load & Use This Model'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (isActive)
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.offline_bolt, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Currently loaded for offline mode',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _unloadModel(provider),
                      icon: const Icon(Icons.eject, size: 20),
                      label: const Text('Unload Model'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unloading frees memory but keeps the model downloaded',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
