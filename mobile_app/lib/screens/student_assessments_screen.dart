import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'take_quiz_screen.dart';
import 'quiz_result_screen.dart';

class StudentAssessmentsScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const StudentAssessmentsScreen({super.key, this.onBackToHome});

  @override
  State<StudentAssessmentsScreen> createState() => _StudentAssessmentsScreenState();
}

class _StudentAssessmentsScreenState extends State<StudentAssessmentsScreen> {
  bool _isLoading = true;
  List<dynamic> _quizzes = [];
  String _selectedFilter = 'ALL'; // 'ALL', 'LIVE', 'PENDING', 'RESULTS'

  @override
  void initState() {
    super.initState();
    _loadAssessments();
  }

  Future<void> _loadAssessments() async {
    setState(() => _isLoading = true);
    try {
      final q = await ApiService.getQuizzes();
      if (mounted) {
        setState(() {
          _quizzes = q;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter quizzes into 3 categories
    final liveTests = _quizzes.where((q) => q['has_submitted'] != true).toList();

    final pendingTests = _quizzes.where((q) {
      if (q['has_submitted'] != true) return false;
      final isResultsPublished = q['is_results_published'] == true;
      final sub = q['submission'] as Map<String, dynamic>?;
      final hasReview = sub != null && (sub['review_breakdown'] as List?)?.isNotEmpty == true;
      // If results are NOT published by trainer, or it's a Google Form awaiting faculty review
      return !isResultsPublished && !hasReview;
    }).toList();

    final declaredResultsTests = _quizzes.where((q) {
      if (q['has_submitted'] != true) return false;
      final isResultsPublished = q['is_results_published'] == true;
      final sub = q['submission'] as Map<String, dynamic>?;
      final hasReview = sub != null && (sub['review_breakdown'] as List?)?.isNotEmpty == true;
      return isResultsPublished || hasReview;
    }).toList();

    return Scaffold(
      backgroundColor: CognitoColors.background,
      appBar: AppBar(
        title: const Text('Live Assessments & Results'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CognitoColors.primary),
            tooltip: 'Refresh Assessments',
            onPressed: _loadAssessments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: CognitoColors.primary),
                  SizedBox(height: 14),
                  Text(
                    'Loading assessments...',
                    style: TextStyle(fontSize: 13, color: CognitoColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAssessments,
              color: CognitoColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header KPI Banner
                    _buildMetricsHeader(
                      liveCount: liveTests.length,
                      pendingCount: pendingTests.length,
                      resultsCount: declaredResultsTests.length,
                    ),
                    const SizedBox(height: 16),

                    // Filter Chips Bar
                    _buildFilterChips(
                      liveCount: liveTests.length,
                      pendingCount: pendingTests.length,
                      resultsCount: declaredResultsTests.length,
                    ),
                    const SizedBox(height: 20),

                    // 1. Live Assessments Container
                    if (_selectedFilter == 'ALL' || _selectedFilter == 'LIVE') ...[
                      _buildSectionHeader(
                        title: 'Live Assessments',
                        subtitle: 'Published tests pending your attempt',
                        icon: Icons.bolt_rounded,
                        iconColor: const Color(0xFF16A34A),
                        badgeText: '${liveTests.length} Available',
                        badgeBg: const Color(0xFFDCFCE7),
                        badgeFg: const Color(0xFF15803D),
                      ),
                      const SizedBox(height: 10),
                      if (liveTests.isEmpty)
                        _buildEmptyStateCard(
                          icon: Icons.check_circle_outline_rounded,
                          title: 'No Pending Tests',
                          message: 'You have attempted all live tests assigned to you! Check back when your faculty publishes new quizzes.',
                        )
                      else
                        ...liveTests.map((q) => _buildLiveQuizCard(q)),
                      const SizedBox(height: 24),
                    ],

                    // 2. Pending Results Container
                    if (_selectedFilter == 'ALL' || _selectedFilter == 'PENDING') ...[
                      _buildSectionHeader(
                        title: 'Pending Results',
                        subtitle: 'Completed tests awaiting faculty result declaration',
                        icon: Icons.hourglass_top_rounded,
                        iconColor: const Color(0xFFD97706),
                        badgeText: '${pendingTests.length} Evaluating',
                        badgeBg: const Color(0xFFFEF3C7),
                        badgeFg: const Color(0xFFB45309),
                      ),
                      const SizedBox(height: 10),
                      if (pendingTests.isEmpty)
                        _buildEmptyStateCard(
                          icon: Icons.hourglass_empty_rounded,
                          title: 'No Pending Results',
                          message: 'You currently have no tests waiting for faculty result declaration.',
                        )
                      else
                        ...pendingTests.map((q) => _buildPendingQuizCard(q)),
                      const SizedBox(height: 24),
                    ],

                    // 3. View Assessment Results Container
                    if (_selectedFilter == 'ALL' || _selectedFilter == 'RESULTS') ...[
                      _buildSectionHeader(
                        title: 'View Assessment Results',
                        subtitle: 'Scores & detailed answer reviews published by trainer',
                        icon: Icons.military_tech_rounded,
                        iconColor: const Color(0xFF2563EB),
                        badgeText: '${declaredResultsTests.length} Declared',
                        badgeBg: const Color(0xFFDBEAFE),
                        badgeFg: const Color(0xFF1D4ED8),
                      ),
                      const SizedBox(height: 10),
                      if (declaredResultsTests.isEmpty)
                        _buildEmptyStateCard(
                          icon: Icons.analytics_outlined,
                          title: 'No Results Declared Yet',
                          message: 'When your trainers release test scores, your performance metrics and answer sheets will be shown here.',
                        )
                      else
                        ...declaredResultsTests.map((q) => _buildDeclaredResultCard(q)),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricsHeader({
    required int liveCount,
    required int pendingCount,
    required int resultsCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CognitoColors.darkBlue, CognitoColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CognitoColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'TRAINERS LIVE ASSESSMENT PORTAL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Official Technical Hub Assessments, Google Form Exams & Concept Quizzes',
            style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricMiniCard('Live Tests', '$liveCount', Colors.greenAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricMiniCard('Pending', '$pendingCount', Colors.amberAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricMiniCard('Declared', '$resultsCount', Colors.lightBlueAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMiniCard(String label, String value, Color highlightColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: highlightColor, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips({
    required int liveCount,
    required int pendingCount,
    required int resultsCount,
  }) {
    final filters = [
      {'id': 'ALL', 'label': 'All (${liveCount + pendingCount + resultsCount})'},
      {'id': 'LIVE', 'label': 'Live Tests ($liveCount)'},
      {'id': 'PENDING', 'label': 'Pending ($pendingCount)'},
      {'id': 'RESULTS', 'label': 'Results ($resultsCount)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                f['label']!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? Colors.white : CognitoColors.textDark,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedFilter = f['id']!),
              backgroundColor: Colors.white,
              selectedColor: CognitoColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? CognitoColors.primary : const Color(0xFFCBD5E1),
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeBg,
    required Color badgeFg,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badgeText,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: badgeFg),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: CognitoColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  // 1. LIVE ASSESSMENT CARD (NOT ATTEMPTED)
  Widget _buildLiveQuizCard(dynamic quiz) {
    final quizId = quiz['id']?.toString() ?? '';
    final title = quiz['title'] ?? 'Assessment Test';
    final courseName = quiz['course_name'] ?? 'Technical Training Track';
    final trainerName = quiz['trainer_name'] ?? 'Faculty Trainer';
    final durationMins = quiz['duration_minutes'] ?? 15;
    final isGoogleForm = quiz['quiz_type'] == 'GOOGLE_FORM' || (quiz['google_form_url'] != null && quiz['google_form_url'].toString().isNotEmpty);
    final qs = (quiz['questions'] as List<dynamic>?) ?? [];
    final totalMarks = qs.isNotEmpty
        ? qs.fold<int>(0, (sum, item) => sum + (int.tryParse(item['marks']?.toString() ?? '1') ?? 1))
        : (int.tryParse(quiz['total_marks']?.toString() ?? '1') ?? 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: Color(0xFF15803D), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          isGoogleForm ? 'GOOGLE FORM EXAM' : 'LIVE MCQ TEST',
                          style: const TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$totalMarks MARKS',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
              Text(
                '⏱ $durationMins MINS',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CognitoColors.textDark),
          ),
          const SizedBox(height: 2),
          Text(
            '$courseName • Prepared by $trainerName',
            style: const TextStyle(fontSize: 11.5, color: CognitoColors.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            isGoogleForm
                ? 'External Google Form examination. Opens within portal. Test closes once timer expires.'
                : 'Questions and options are randomized for each student. Total $totalMarks marks. 1 Attempt only.',
            style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TakeQuizScreen(
                      quizId: quizId,
                      quizTitle: title,
                    ),
                  ),
                ).then((_) => _loadAssessments());
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isGoogleForm ? 'OPEN GOOGLE FORM TEST' : 'START TEST NOW ($durationMins MINS)',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.5),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: CognitoColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. PENDING RESULTS CARD (WAITING FOR TRAINER DECLARATION)
  Widget _buildPendingQuizCard(dynamic quiz) {
    final title = quiz['title'] ?? 'Assessment Test';
    final courseName = quiz['course_name'] ?? 'Technical Training Track';
    final trainerName = quiz['trainer_name'] ?? 'Faculty Trainer';
    final isGoogleForm = quiz['quiz_type'] == 'GOOGLE_FORM' || (quiz['google_form_url'] != null && quiz['google_form_url'].toString().isNotEmpty);
    final sub = quiz['submission'] as Map<String, dynamic>?;
    final submittedAt = sub?['submitted_at']?.toString() ?? '';
    final timeTaken = sub?['time_taken_seconds'] ?? 0;
    final mins = timeTaken ~/ 60;
    final secs = timeTaken % 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'ATTEMPT RECORDED',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: Color(0xFFB45309), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'RESULT PENDING',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CognitoColors.textDark),
          ),
          const SizedBox(height: 2),
          Text(
            '$courseName • Evaluated by $trainerName',
            style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          if (submittedAt.isNotEmpty || timeTaken > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (submittedAt.isNotEmpty)
                  Text(
                    '📅 ${submittedAt.length > 19 ? submittedAt.substring(0, 19).replaceAll("T", " ") : submittedAt}',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
                if (timeTaken > 0)
                  Text(
                    '⏱️ Time: ${mins > 0 ? "${mins}m " : ""}${secs}s',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_rounded, size: 16, color: Color(0xFF475569)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isGoogleForm
                        ? 'Google Form submission verified. Final marks and evaluation will be declared by your trainer.'
                        : '🔒 Awaiting faculty result declaration. Scores and detailed answer breakdown will appear once published by trainer.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. DECLARED RESULTS CARD (SCORES & ANSWER SHEET RELEASED)
  Widget _buildDeclaredResultCard(dynamic quiz) {
    final title = quiz['title'] ?? 'Assessment Test';
    final courseName = quiz['course_name'] ?? 'Technical Training Track';
    final trainerName = quiz['trainer_name'] ?? 'Faculty Trainer';
    final sub = quiz['submission'] as Map<String, dynamic>? ?? {};
    final score = sub['score'] ?? 0;
    final qs = (quiz['questions'] as List<dynamic>?) ?? [];
    final totalMarks = qs.isNotEmpty
        ? qs.fold<int>(0, (sum, item) => sum + (int.tryParse(item['marks']?.toString() ?? '1') ?? 1))
        : (sub['total_marks'] ?? quiz['total_marks'] ?? 1);
    final pct = (sub['percentage'] ?? (totalMarks > 0 ? ((score / totalMarks) * 100).round() : 0)).toInt();
    final reviewData = (sub['review_breakdown'] as List<dynamic>?) ?? [];
    final submittedAt = sub['submitted_at']?.toString() ?? '';
    final isGoogleForm = quiz['quiz_type'] == 'GOOGLE_FORM';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'RESULTS DECLARED',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pct >= 60 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: pct >= 60 ? const Color(0xFF86EFAC) : const Color(0xFFFECACA)),
                ),
                child: Text(
                  isGoogleForm ? 'COMPLETED' : '$pct% • ${pct >= 60 ? "PASSED" : "NEEDS RETEST"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: pct >= 60 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CognitoColors.textDark),
          ),
          const SizedBox(height: 2),
          Text(
            '$courseName • Conducted by $trainerName',
            style: const TextStyle(fontSize: 11.5, color: CognitoColors.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Score Summary Box - Fully responsive columns with scale-down
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildScoreStat('SCORE', isGoogleForm ? 'Submitted' : '$score / $totalMarks', const Color(0xFF0F172A))),
                Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
                Expanded(child: _buildScoreStat('ACCURACY', '$pct%', pct >= 60 ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
                Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
                Expanded(child: _buildScoreStat('STATUS', pct >= 60 ? 'Distinction' : 'Review Needed', const Color(0xFF2563EB))),
              ],
            ),
          ),

          if (submittedAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Submitted on: ${submittedAt.length > 19 ? submittedAt.substring(0, 19).replaceAll("T", " ") : submittedAt}',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 12),

          // Action Button: View Detailed Answer Sheet / Solutions
          if (reviewData.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizResultScreen(
                        quizTitle: title,
                        submission: sub,
                        reviewData: reviewData,
                        isReviewMode: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'VIEW DETAILED ANSWER SHEET',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreStat(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: valueColor),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
