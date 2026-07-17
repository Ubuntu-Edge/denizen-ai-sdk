import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/offline_model_provider.dart';
import '../services/offline_ai_service.dart';

/// Example widget showing how to integrate offline AI mode
/// This demonstrates switching between online and offline modes
class OfflineAIExample extends StatefulWidget {
  const OfflineAIExample({super.key});

  @override
  State<OfflineAIExample> createState() => _OfflineAIExampleState();
}

class _OfflineAIExampleState extends State<OfflineAIExample> {
  bool _isLoadingModel = false;

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final offlineModelProvider = Provider.of<OfflineModelProvider>(context);
    final offlineAIService = OfflineAIService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Mode Selection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Mode Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current AI Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chatProvider.aiMode == AIMode.online ? 'Online (HuggingFace API)' : 'Offline (llama.cpp)',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offlineAIService.getModelInfo()?.toString() ?? 'No model info available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mode Selection Buttons
            const Text(
              'Select AI Mode:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Online Mode Button
            ElevatedButton.icon(
              onPressed: () {
                chatProvider.setAIMode(AIMode.online);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Switched to Online Mode')),
                );
              },
              icon: const Icon(Icons.cloud),
              label: const Text('Use Online Mode'),
              style: ElevatedButton.styleFrom(
                backgroundColor: chatProvider.aiMode == AIMode.online
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),

            // Offline Mode Button
            ElevatedButton.icon(
              onPressed: offlineAIService.isModelLoaded
                  ? () {
                      chatProvider.setAIMode(AIMode.offline);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Switched to Offline Mode')),
                      );
                    }
                  : null,
              icon: const Icon(Icons.storage),
              label: Text(
                offlineAIService.isModelLoaded
                    ? 'Use Offline Mode'
                    : 'Offline Mode (No Model Loaded)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: chatProvider.aiMode == AIMode.offline
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Offline Model Management
            const Text(
              'Offline Models:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Model List
            Expanded(
              child: offlineModelProvider.models.isEmpty
                  ? const Center(
                      child: Text('No offline models available'),
                    )
                  : ListView.builder(
                      itemCount: offlineModelProvider.models.length,
                      itemBuilder: (context, index) {
                        final model = offlineModelProvider.models[index];
                        final isActive = offlineModelProvider.activeModel?.id == model.id;

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              model.isDownloaded ? Icons.check_circle : Icons.cloud_download,
                              color: model.isDownloaded ? Colors.green : Colors.grey,
                            ),
                            title: Text(model.name),
                            subtitle: Text(
                              '${model.sizeMB.toStringAsFixed(1)} MB\n'
                              'Author: ${model.author}',
                            ),
                            trailing: isActive
                                ? const Chip(
                                    label: Text('Active'),
                                    backgroundColor: Colors.green,
                                  )
                                : null,
                            onTap: model.isDownloaded
                                ? () async {
                                    await _loadModel(context, model, offlineModelProvider);
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
            ),

            // Load Model Button (if model is active but not loaded)
            if (offlineModelProvider.activeModel != null &&
                !offlineAIService.isModelLoaded)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton.icon(
                  onPressed: _isLoadingModel
                      ? null
                      : () async {
                          await _loadModel(
                            context,
                            offlineModelProvider.activeModel!,
                            offlineModelProvider,
                          );
                        },
                  icon: _isLoadingModel
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isLoadingModel ? 'Loading...' : 'Load Active Model'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadModel(
    BuildContext context,
    dynamic model,
    OfflineModelProvider offlineModelProvider,
  ) async {
    setState(() => _isLoadingModel = true);

    try {
      final modelPath = await offlineModelProvider.getModelFullPath(model);
      if (modelPath == null) {
        throw Exception('Model path is undefined');
      }

      final offlineAIService = OfflineAIService.instance;
      final success = await offlineAIService.loadModel(
        modelPath: modelPath,
        model: model,
        contextParams: offlineModelProvider.contextParams,
      );

      if (success) {
        await offlineModelProvider.setActiveModel(model);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Model loaded: ${model.name}')),
          );
        }
      } else {
        throw Exception('Failed to load model');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading model: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingModel = false);
    }
  }
}
