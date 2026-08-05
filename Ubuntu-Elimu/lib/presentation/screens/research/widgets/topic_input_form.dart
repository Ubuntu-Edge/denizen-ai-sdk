import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class TopicInputForm extends StatefulWidget {
  final Function(String topic, String depth, String length) onGenerate;
  final bool isGenerating;

  const TopicInputForm({
    required this.onGenerate,
    required this.isGenerating,
    super.key,
  });

  @override
  State<TopicInputForm> createState() => _TopicInputFormState();
}

class _TopicInputFormState extends State<TopicInputForm> {
  final TextEditingController _controller = TextEditingController();
  String _depth = 'Brief'; // Brief / Comprehensive
  String _length = 'Short'; // Short / Long

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final topic = _controller.text.trim();
    if (topic.isEmpty) return;
    widget.onGenerate(topic, _depth, _length);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UEColors.surface,
        border: Border.all(color: UEColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GENERATE RESEARCH REPORT',
            style: UETypography.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: UEColors.textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),

          // Topic Input TextField
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: UEColors.bg,
              border: Border.all(color: UEColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _controller,
              style: UETypography.inter(fontSize: 13, color: UEColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter topic (e.g., Photosynthesis pathways)',
                hintStyle: UETypography.inter(fontSize: 13, color: UEColors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Parameter Selectors
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Depth',
                  value: _depth,
                  options: ['Brief', 'Comprehensive'],
                  onChanged: (val) {
                    if (val != null) setState(() => _depth = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'Length',
                  value: _length,
                  options: ['Short', 'Long'],
                  onChanged: (val) {
                    if (val != null) setState(() => _length = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Submit Button
          GestureDetector(
            onTap: widget.isGenerating ? null : _submit,
            child: Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.isGenerating ? UEColors.bg : UEColors.accent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.isGenerating ? UEColors.border : Colors.transparent,
                  width: 0.5,
                ),
              ),
              child: Center(
                child: widget.isGenerating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: UEColors.accent,
                        ),
                      )
                    : Text(
                        'Generate Offline Report',
                        style: UETypography.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: UETypography.inter(fontSize: 10, color: UEColors.textMuted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: UEColors.bg,
            border: Border.all(color: UEColors.border, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: UEColors.surface,
              icon: Icon(TablerIcons.chevron_down, color: UEColors.textMuted, size: 14),
              style: UETypography.inter(fontSize: 12, color: UEColors.textPrimary),
              onChanged: onChanged,
              items: options.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
