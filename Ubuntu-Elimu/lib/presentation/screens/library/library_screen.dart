import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../providers/document_provider.dart';
import '../../../models/document.dart';
import 'widgets/document_card.dart';

// NEW: AI workspace screen (you will implement next)
import 'document_workspace_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);

    return Scaffold(
      backgroundColor: UEColors.bg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildSearchBar(context, docProvider),
            const SizedBox(height: 14),
            _buildCategoryChips(context, docProvider),
            const SizedBox(height: 16),
            Expanded(
              child: _buildDocumentList(context, docProvider),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _simulateUpload(context, docProvider),
        backgroundColor: UEColors.accent,
        label: Text(
          'Upload Doc',
          style: UETypography.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: const Icon(TablerIcons.plus, color: Colors.white, size: 16),
      ),
    );
  }

  // ================= SEARCH =================
  Widget _buildSearchBar(BuildContext context, DocumentProvider provider) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: UEColors.surface,
        border: Border.all(color: UEColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(TablerIcons.search,
                color: UEColors.textMuted, size: 18),
          ),
          Expanded(
            child: TextField(
              style: UETypography.inter(
                  fontSize: 13, color: UEColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search offline files...',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) => provider.setSearchQuery(val),
            ),
          ),
        ],
      ),
    );
  }

  // ================= FILTERS =================
  Widget _buildCategoryChips(
      BuildContext context, DocumentProvider provider) {
    final categories = ['all', 'pdf', 'pptx', 'docx'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = provider.selectedCategory == cat;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => provider.setSelectedCategory(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? UEColors.iconBg
                      : UEColors.surface,
                  border: Border.all(
                    color: isSelected
                        ? UEColors.accent
                        : UEColors.border,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cat.toUpperCase(),
                  style: UETypography.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? UEColors.accent
                        : UEColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================= DOCUMENT LIST =================
  Widget _buildDocumentList(
      BuildContext context, DocumentProvider provider) {
    final docs = provider.documents;

    if (docs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.file_off,
                size: 36, color: UEColors.border),
            SizedBox(height: 12),
            Text(
              'No matching offline files found',
              style: TextStyle(
                color: UEColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];

        return GestureDetector(
          onTap: () => _openDocumentWorkspace(context, doc),
          onLongPress: () => _showDocumentActions(context, doc),
          child: DocumentCard(doc: doc),
        );
      },
    );
  }

  // ================= DOCUMENT ACTIONS (AI CORE) =================
  void _showDocumentActions(BuildContext context, doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: UEColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                doc.name,
                style: UETypography.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: UEColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _actionButton(
                icon: TablerIcons.sparkles,
                label: "Summarize Content",
                onTap: () {
                  Navigator.pop(context);
                  _runAI(context, doc, "summary");
                },
              ),

              _actionButton(
                icon: TablerIcons.calendar,
                label: "Generate Study Plan",
                onTap: () {
                  Navigator.pop(context);
                  _runAI(context, doc, "study_plan");
                },
              ),

              _actionButton(
                icon: TablerIcons.cards,
                label: "Create Flashcards",
                onTap: () {
                  Navigator.pop(context);
                  _runAI(context, doc, "flashcards");
                },
              ),

              _actionButton(
                icon: TablerIcons.book,
                label: "Open Learning View",
                onTap: () {
                  Navigator.pop(context);
                  _openDocumentWorkspace(context, doc);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= ACTION BUTTON =================
  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: UEColors.accent, size: 18),
      title: Text(
        label,
        style: UETypography.inter(
          fontSize: 12,
          color: UEColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  // ================= AI PROCESSING (MOCK) =================
  void _runAI(BuildContext context, doc, String mode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Processing ${doc.name} → $mode"),
        backgroundColor: UEColors.surface,
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentWorkspaceScreen(
            document: doc,
            mode: mode,
          ),
        ),
      );
    });
  }

  // ================= OPEN WORKSPACE =================
  void _openDocumentWorkspace(BuildContext context, doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentWorkspaceScreen(
          document: doc,
          mode: "reader",
        ),
      ),
    );
  }

  // ================= UPLOAD SIMULATION =================
  void _simulateUpload(BuildContext context, DocumentProvider provider) {
    final random = Random();

    final names = [
      'Anatomy Exam Prep — Q2.pdf',
      'Calculus Formulas Guide.docx',
      'Advanced Astrophysics presentation.pptx',
      'Kiswahili Grammar guide.pdf',
      'Microeconomics lecture slides.pptx'
    ];

    final docTypes = [
      DocType.pdf,
      DocType.docx,
      DocType.pptx,
      DocType.pdf,
      DocType.pptx
    ];

    final idx = random.nextInt(names.length);

    provider.pickAndUploadDocument();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Uploaded ${names[idx]} successfully'),
        backgroundColor: UEColors.surface,
      ),
    );
  }
}