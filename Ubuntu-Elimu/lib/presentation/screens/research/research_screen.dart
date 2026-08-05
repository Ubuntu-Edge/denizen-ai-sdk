import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../providers/document_provider.dart';
import '../../../providers/offline_model_provider.dart';
import '../../../services/offline_ai_service.dart';
import 'widgets/topic_input_form.dart';
import 'widgets/report_output_view.dart';

class ResearchScreen extends StatefulWidget {
  const ResearchScreen({super.key});

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  bool _isGenerating = false;
  String? _reportTopic;
  String? _reportContent;
  List<String> _reportSources = [];
  String? _error;

  Future<void> _generateReport(String topic, String depth, String length) async {
    final modelProvider = context.read<OfflineModelProvider>();
    final docProvider = context.read<DocumentProvider>();

    if (!modelProvider.hasActiveModel) {
      setState(() => _error = 'No model loaded — go to Settings to download and activate one.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final related = docProvider.findRelevantAcrossLibrary(topic);
      final contextChunks = related.expand((e) => e.value).toList();
      final sourceNames = related.map((e) => e.key.name).toList();

      final content = await OfflineAIService.instance.generateReport(
        topic: topic,
        depth: depth,
        length: length,
        contextChunks: contextChunks,
      );

      setState(() {
        _reportTopic = topic;
        _reportContent = content;
        _reportSources = sourceNames;
      });
    } catch (e) {
      setState(() => _error = 'Something went wrong generating this report: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _clearReport() {
    setState(() {
      _reportTopic = null;
      _reportContent = null;
      _reportSources = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final modelProvider = context.watch<OfflineModelProvider>();

    return Scaffold(
      backgroundColor: UEColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Research', style: UETypography.h3),
              const SizedBox(height: 4),
              Text(
                'Generate a study report on any topic, grounded in your own library when relevant.',
                style: UETypography.inter(fontSize: 12, color: UEColors.textMuted),
              ),
              const SizedBox(height: 16),
              if (!modelProvider.hasActiveModel)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: UEColors.pdfBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'No model loaded — go to Settings to download and activate one.',
                    style: UETypography.inter(fontSize: 11, color: UEColors.pdfFg),
                  ),
                ),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: UEColors.pdfBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: UETypography.inter(fontSize: 11, color: UEColors.pdfFg),
                  ),
                ),
              TopicInputForm(
                isGenerating: _isGenerating,
                onGenerate: _generateReport,
              ),
              if (_reportContent != null) ...[
                const SizedBox(height: 20),
                ReportOutputView(
                  topic: _reportTopic ?? '',
                  content: _reportContent!,
                  sources: _reportSources,
                  onClear: _clearReport,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
