import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../models/offline_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/offline_model_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final modelProvider = Provider.of<OfflineModelProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildSectionTitle('OFFLINE MODELS'),
          const SizedBox(height: 10),
          if (modelProvider.error != null) ...[
            _buildErrorBanner(modelProvider.error!),
            const SizedBox(height: 10),
          ],
          ...modelProvider.models.map(
                (model) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildModelCard(context, modelProvider, model),
            ),
          ),
          const SizedBox(height: 14),
          _buildSectionTitle('PREFERENCES'),
          const SizedBox(height: 10),
          _buildPreferenceSwitches(context, settings),
          const SizedBox(height: 24),
          _buildSectionTitle('LOCAL SYSTEM INFO'),
          const SizedBox(height: 10),
          _buildSystemInfoCard(context, modelProvider),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: UETypography.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: UEColors.textMuted,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UEColors.pdfBg,
        border: Border.all(color: UEColors.pdfFg.withOpacity(0.4), width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(TablerIcons.alert_circle, color: UEColors.pdfFg, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: UETypography.inter(fontSize: 11, color: UEColors.pdfFg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(
      BuildContext context,
      OfflineModelProvider modelProvider,
      OfflineModel model,
      ) {
    final isActive = modelProvider.activeModel?.id == model.id;
    final isDownloading = !model.isDownloaded && model.downloadProgress > 0;
    final isLoadingIntoMemory = isActive && modelProvider.isContextLoading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UEColors.surface,
        border: Border.all(
          color: isActive ? UEColors.accent.withOpacity(0.6) : UEColors.border,
          width: isActive ? 1 : 0.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(TablerIcons.database, color: UEColors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: UETypography.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: UEColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${model.author} · ${model.sizeMB.toStringAsFixed(0)} MB · ${model.quantization}',
                      style: UETypography.inter(fontSize: 11, color: UEColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      model.description,
                      style: UETypography.inter(fontSize: 11, color: UEColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: UEColors.greenBg,
                    border: Border.all(color: UEColors.greenBorder, width: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Active',
                    style: UETypography.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: UEColors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: model.downloadProgress,
                backgroundColor: UEColors.iconBg,
                color: UEColors.accent,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloading… ${(model.downloadProgress * 100).toInt()}%',
                  style: UETypography.inter(fontSize: 11, color: UEColors.textMuted),
                ),
                GestureDetector(
                  onTap: () => modelProvider.cancelDownload(model.id),
                  child: Text(
                    'Cancel',
                    style: UETypography.inter(
                      fontSize: 11,
                      color: UEColors.pdfFg,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (model.isDownloaded) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: isLoadingIntoMemory
                      ? Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading into memory…',
                        style: UETypography.inter(fontSize: 11, color: UEColors.textMuted),
                      ),
                    ],
                  )
                      : GestureDetector(
                    onTap: isActive ? null : () => modelProvider.setActiveModel(model),
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: isActive ? UEColors.iconBg : UEColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isActive ? 'Currently in use' : 'Use this model',
                        style: UETypography.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? UEColors.textMuted : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => modelProvider.deleteModel(model),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: UEColors.pdfFg, width: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Delete',
                      style: UETypography.inter(fontSize: 11, color: UEColors.pdfFg, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: () => modelProvider.downloadModel(model),
              child: Container(
                height: 38,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: UEColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Download (${model.sizeMB.toStringAsFixed(0)} MB)',
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
        ],
      ),
    );
  }

  Widget _buildPreferenceSwitches(BuildContext context, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: UEColors.surface,
        border: Border.all(color: UEColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              'Socratic Coaching Mode',
              style: UETypography.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w500, color: UEColors.textPrimary),
            ),
            subtitle: Text(
              'Guides learning by asking step-by-step questions instead of solving directly.',
              style: UETypography.inter(fontSize: 11, color: UEColors.textMuted),
            ),
            value: settings.socraticMode,
            activeThumbColor: UEColors.accent,
            activeTrackColor: UEColors.accent.withOpacity(0.5),
            onChanged: (val) => settings.toggleSocraticMode(val),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: UEColors.border, height: 0.5),
          ),
          SwitchListTile(
            title: Text(
              'System Power Mode',
              style: UETypography.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w500, color: UEColors.textPrimary),
            ),
            subtitle: Text(
              'Optimizes CPU cores for local model inference speeds.',
              style: UETypography.inter(fontSize: 11, color: UEColors.textMuted),
            ),
            value: settings.powerMode,
            activeThumbColor: UEColors.accent,
            activeTrackColor: UEColors.accent.withOpacity(0.5),
            onChanged: (val) => settings.togglePowerMode(val),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard(BuildContext context, OfflineModelProvider modelProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UEColors.surface,
        border: Border.all(color: UEColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          FutureBuilder<int>(
            future: modelProvider.getUsedStorageBytes(),
            builder: (context, snapshot) {
              final usedMB = ((snapshot.data ?? 0) / (1024 * 1024)).toStringAsFixed(1);
              return _buildInfoRow('Local Storage Used', '$usedMB MB');
            },
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            'Active Model',
            modelProvider.activeModel?.name ?? 'None loaded',
          ),
          const SizedBox(height: 10),
          _buildInfoRow('App Version', '1.0.0 (Ubuntu-Edge Custom)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: UETypography.inter(fontSize: 12, color: UEColors.textMuted),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: UETypography.inter(fontSize: 12, color: UEColors.textPrimary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
