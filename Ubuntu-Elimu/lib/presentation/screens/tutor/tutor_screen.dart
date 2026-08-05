import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../models/chat_message.dart';
import '../../../models/document.dart';
import '../../../models/offline_model.dart';
import '../../../providers/session_provider.dart';
import '../../../providers/document_provider.dart';
import '../../../providers/offline_model_provider.dart';
import '../../../providers/settings_provider.dart';
import 'widgets/doc_context_bar.dart';
import 'widgets/model_lang_controls.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/language_sheet.dart';

// Maps the two Model pills to real catalog entries in default_offline_models.dart.
const String _liteModelId = 'llama-3.2-1b-q8';
const String _powerModelId = 'llama-3.2-3b-q4';

class TutorScreen extends StatefulWidget {
  const TutorScreen({super.key});

  @override
  State<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends State<TutorScreen> {
  final ScrollController _scrollController = ScrollController();

  // Language has no backend persistence yet — kept as local UI state and
  // passed straight into SessionProvider.sendMessage() per message.
  Language _language = Language.english;
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(SessionProvider session, DocumentProvider docs, bool socratic, String text) {
    session.sendMessage(
      text,
      docProvider: docs,
      socratic: socratic,
      language: _language.fullName,
    );
    _scrollToBottom();
  }

  void _showDocPicker(BuildContext context, SessionProvider session, DocumentProvider docs) {
    if (docs.documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No documents yet — add one from the Library tab first.'),
          backgroundColor: UEColors.bgCard,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: UEColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Study with a document', style: UETypography.h3),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.documents.length,
                  separatorBuilder: (_, __) => const Divider(color: UEColors.border, height: 1),
                  itemBuilder: (_, i) {
                    final doc = docs.documents[i];
                    return ListTile(
                      leading: Icon(_iconForType(doc.type), color: UEColors.textMuted),
                      title: Text(doc.name, style: UETypography.bodyMd),
                      subtitle: Text(
                        doc.isProcessed ? 'Ready' : 'Still processing…',
                        style: UETypography.caption,
                      ),
                      onTap: doc.isProcessed
                          ? () {
                        session.setActiveDocument(doc.id, doc.name);
                        Navigator.pop(sheetContext);
                      }
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(DocType type) {
    switch (type) {
      case DocType.pdf:
        return Icons.picture_as_pdf_rounded;
      case DocType.pptx:
        return Icons.slideshow_rounded;
      case DocType.docx:
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  void _openCitation(CitationRef citation) {
    // Real inference doesn't produce structured citations yet — tutorStream
    // returns plain text. Wiring this properly means having the model emit
    // a page/quote reference alongside its answer. Left as a follow-up.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${citation.docName} p.${citation.page}'),
        backgroundColor: UEColors.bgCard,
      ),
    );
  }

  void _handleModelChange(BuildContext context, OfflineModelProvider modelProvider, ModelMode mode) {
    final targetId = mode == ModelMode.power ? _powerModelId : _liteModelId;
    final target = modelProvider.models.where((m) => m.id == targetId).firstOrNull;

    if (target == null) return;

    if (!target.isDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${target.name} isn\'t downloaded yet — grab it in Settings first.'),
          backgroundColor: UEColors.bgCard,
        ),
      );
      return;
    }

    modelProvider.setActiveModel(target);
  }

  ModelMode _modeForActiveModel(OfflineModel? active) {
    if (active?.id == _powerModelId) return ModelMode.power;
    return ModelMode.lite;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final docs = context.watch<DocumentProvider>();
    final modelProvider = context.watch<OfflineModelProvider>();
    final settings = context.watch<SettingsProvider>();

    if (session.chatMessages.length != _lastMessageCount) {
      _lastMessageCount = session.chatMessages.length;
      _scrollToBottom();
    }

    final activeDoc = session.activeDocumentId == null
        ? null
        : docs.documents.where((d) => d.id == session.activeDocumentId).firstOrNull;

    return Scaffold(
      backgroundColor: UEColors.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(onBack: () => Navigator.maybePop(context)),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: UEColors.bgCard, width: 0.5)),
              ),
              child: Column(
                children: [
                  DocContextBar(
                    activeDoc: activeDoc,
                    onChangeTap: () => _showDocPicker(context, session, docs),
                  ),
                  const SizedBox(height: 10),
                  ModelLangControls(
                    selectedModel: _modeForActiveModel(modelProvider.activeModel),
                    selectedLanguage: _language,
                    socraticMode: settings.socraticMode,
                    onModelChanged: (m) => _handleModelChange(context, modelProvider, m),
                    onLanguageTap: () => LanguageSheet.show(
                      context,
                      current: _language,
                      onSelected: (l) => setState(() => _language = l),
                    ),
                  ),
                ],
              ),
            ),
            if (!modelProvider.hasActiveModel)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: UEColors.pdfBg,
                child: Text(
                  'No model loaded — go to Settings to download and activate one.',
                  style: UETypography.inter(fontSize: 11, color: UEColors.pdfFg),
                ),
              ),
            const _SessionDivider(),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                itemCount: session.chatMessages.length + (session.isGenerating ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (index == session.chatMessages.length) {
                    return const TypingIndicator();
                  }
                  final msg = session.chatMessages[index];
                  return ChatBubble(
                    message: msg,
                    onCitationTap: msg.citation != null ? () => _openCitation(msg.citation!) : null,
                  );
                },
              ),
            ),
            ChatInputBar(
              onSend: (text) => _handleSend(session, docs, settings.socraticMode, text),
              isTyping: session.isGenerating,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(
              Icons.arrow_back_rounded,
              color: UEColors.textMuted,
              size: 22,
            ),
          ),
          const Spacer(),
          Text('AI Tutor', style: UETypography.h3),
          const Spacer(),
          const Icon(
            Icons.more_horiz_rounded,
            color: UEColors.textMuted,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _SessionDivider extends StatelessWidget {
  const _SessionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Session started · Today',
        style: UETypography.caption.copyWith(
          color: UEColors.textDim,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
