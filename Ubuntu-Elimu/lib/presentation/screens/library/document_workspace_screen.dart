import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

class DocumentWorkspaceScreen extends StatefulWidget {
  final dynamic document;
  final String mode;

  const DocumentWorkspaceScreen({
    super.key,
    required this.document,
    required this.mode,
  });

  @override
  State<DocumentWorkspaceScreen> createState() =>
      _DocumentWorkspaceScreenState();
}

class _DocumentWorkspaceScreenState extends State<DocumentWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);

    // Auto-open based on mode
    switch (widget.mode) {
      case "summary":
        _tabController.index = 1;
        break;
      case "study_plan":
        _tabController.index = 2;
        break;
      case "flashcards":
        _tabController.index = 3;
        break;
      default:
        _tabController.index = 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;

    return Scaffold(
      backgroundColor: UEColors.bg,
      appBar: AppBar(
        backgroundColor: UEColors.surface,
        elevation: 0,
        title: Text(
          doc.name,
          style: UETypography.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: UEColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: UEColors.accent,
          labelColor: UEColors.accent,
          unselectedLabelColor: UEColors.textMuted,
          tabs: const [
            Tab(icon: Icon(TablerIcons.file_text, size: 18)),
            Tab(icon: Icon(TablerIcons.sparkles, size: 18)),
            Tab(icon: Icon(TablerIcons.calendar, size: 18)),
            Tab(icon: Icon(TablerIcons.cards, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReaderTab(doc),
          _buildSummaryTab(doc),
          _buildStudyPlanTab(doc),
          _buildFlashcardsTab(doc),
        ],
      ),
    );
  }

  // ================= ORIGINAL READER =================
  Widget _buildReaderTab(doc) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UEColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "📄 Original Document Viewer Placeholder\n\n"
          "Here you will render PDF/DOCX content using a file viewer.\n\n"
          "File: ${doc.name}",
          style: UETypography.inter(
            fontSize: 13,
            color: UEColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ================= AI SUMMARY =================
  Widget _buildSummaryTab(doc) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle("📘 Structured Notes"),
        _card("""
• Machine Learning is a method of teaching computers to learn patterns from data  
• It improves automatically through experience  
• Used in prediction, classification, and recommendation systems  
        """),

        _sectionTitle("🧠 Key Concepts"),
        _card("""
• Supervised Learning  
• Unsupervised Learning  
• Reinforcement Learning  
        """),

        _sectionTitle("🎯 Exam Focus"),
        _card("""
• Difference between supervised vs unsupervised learning  
• Real-world applications  
• Basic model workflow  
        """),
      ],
    );
  }

  // ================= STUDY PLAN =================
  Widget _buildStudyPlanTab(doc) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle("📅 3-Day Study Plan"),

        _planCard("Day 1", "Introduction + Core Concepts", "30–45 min"),
        _planCard("Day 2", "Deep Dive Topics", "45–60 min"),
        _planCard("Day 3", "Revision + Practice Questions", "60 min"),

        const SizedBox(height: 12),

        _sectionTitle("⚡ Tips"),
        _card("""
• Study in short focused sessions  
• Revise active recall questions  
• Avoid passive reading only  
        """),
      ],
    );
  }

  // ================= FLASHCARDS =================
  Widget _buildFlashcardsTab(doc) {
    final cards = [
      {
        "q": "What is Machine Learning?",
        "a": "A method where computers learn patterns from data."
      },
      {
        "q": "What is supervised learning?",
        "a": "Learning using labeled data."
      },
      {
        "q": "Give one application of ML",
        "a": "Recommendation systems (e.g., Netflix, YouTube)"
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];

        return Card(
          color: UEColors.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            iconColor: UEColors.accent,
            collapsedIconColor: UEColors.textMuted,
            title: Text(
              card["q"]!,
              style: UETypography.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: UEColors.textPrimary,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  card["a"]!,
                  style: UETypography.inter(
                    fontSize: 13,
                    color: UEColors.textMuted,
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // ================= UI HELPERS =================
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        text,
        style: UETypography.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: UEColors.textPrimary,
        ),
      ),
    );
  }

  Widget _card(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UEColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: UETypography.inter(
          fontSize: 13,
          color: UEColors.textPrimary,
        ),
      ),
    );
  }

  Widget _planCard(String day, String topic, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UEColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day,
                style: UETypography.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: UEColors.textPrimary,
                ),
              ),
              Text(
                topic,
                style: UETypography.inter(
                  fontSize: 12,
                  color: UEColors.textMuted,
                ),
              ),
            ],
          ),
          Text(
            time,
            style: UETypography.inter(
              fontSize: 12,
              color: UEColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}