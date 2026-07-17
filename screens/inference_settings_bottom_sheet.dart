import 'package:flutter/material.dart';
import '../services/ai_service.dart';

/// Bottom sheet for adjusting AI inference settings.
///
/// NOTE: The original depends on an AIPal model for initial values.
/// For the standalone architecture, this uses simple default values.
/// Developers should adapt the constructor to accept their own config model.
class InferenceSettingsBottomSheet extends StatefulWidget {
  final double initialTemperature;
  final double initialTopP;
  final int initialMaxTokens;
  final VoidCallback onSettingsChanged;

  const InferenceSettingsBottomSheet({
    super.key,
    this.initialTemperature = 0.7,
    this.initialTopP = 0.9,
    this.initialMaxTokens = 450,
    required this.onSettingsChanged,
  });

  @override
  State<InferenceSettingsBottomSheet> createState() =>
      _InferenceSettingsBottomSheetState();
}

class _InferenceSettingsBottomSheetState
    extends State<InferenceSettingsBottomSheet> {
  late double _temperature;
  late double _topP;
  late int _nCtx;

  @override
  void initState() {
    super.initState();
    _temperature = widget.initialTemperature;
    _topP = widget.initialTopP;
    _nCtx = widget.initialMaxTokens;
  }

  void _applySettings() {
    // Update AIService with the new settings from the sliders
    AIService.instance.setTemperature(_temperature);
    AIService.instance.setTopP(_topP);
    AIService.instance.setContextSize(_nCtx);

    widget.onSettingsChanged();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Inference Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Temperature Slider
              _buildSliderSetting(
                label: 'Temperature',
                value: _temperature,
                min: 0.0,
                max: 2.0,
                step: 0.1,
                onChanged: (v) => setState(() => _temperature = v),
                description:
                    'Controls randomness (lower = more focused, higher = more creative)',
              ),
              const SizedBox(height: 24),

              // Top-P Slider
              _buildSliderSetting(
                label: 'Top-P',
                value: _topP,
                min: 0.0,
                max: 1.0,
                step: 0.1,
                onChanged: (v) => setState(() => _topP = v),
                description: 'Nucleus sampling (0.9 = diverse, 0.1 = focused)',
              ),
              const SizedBox(height: 24),

              // nCtx (Context Size) Slider
              _buildSliderSetting(
                label: 'Max New Tokens',
                value: _nCtx.toDouble(),
                min: 256,
                max: 4096,
                step: 256,
                onChanged: (v) => setState(() => _nCtx = v.toInt()),
                description:
                    'Max tokens in the AI\'s response (limits length and cost)',
              ),
              const SizedBox(height: 20),

              // Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Text(
                  '💡 Tip: Higher values for Temperature and Top-P lead to more creative but less predictable responses.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 20),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _applySettings,
                  icon: const Icon(Icons.check),
                  label: const Text('Apply Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required ValueChanged<double> onChanged,
    required String description,
  }) {
    bool isIntSlider = step >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isIntSlider ? value.toInt().toString() : value.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: isIntSlider ? ((max - min) / step).round() : null,
          label: isIntSlider ? value.toInt().toString() : value.toStringAsFixed(1),
          onChanged: onChanged,
          activeColor: Colors.blue,
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
