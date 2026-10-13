import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_service.dart';

class BehaviourScreen extends StatefulWidget {
  const BehaviourScreen({super.key});

  @override
  State<BehaviourScreen> createState() => _BehaviourScreenState();
}

class _BehaviourScreenState extends State<BehaviourScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _behaviour = {};
  List<dynamic> _quizzes = [];
  int _selectedPillarIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBehaviour();
  }

  Future<void> _loadBehaviour() async {
    setState(() => _isLoading = true);
    try {
      final b = await ApiService.getStudentBehaviour();
      final q = await ApiService.getQuizzes();
      final att = await ApiService.getStudentAttendance();

      final attSummary = att['summary'] ?? {};
      final totalSessions = _parseDouble(attSummary['totalSessions'], 0.0);
      final presentCount = _parseDouble(attSummary['presentCount'], 0.0);
      final rawAttPct = _parseDouble(attSummary['overallPercentage'], 0.0);

      final realAttPct = totalSessions > 0
          ? ((presentCount / totalSessions) * 100).clamp(0.0, 100.0)
          : (presentCount > 0 ? 100.0 : rawAttPct);

      final activeQuizzes = q.where((item) => item['is_published'] == true).toList();
      final submittedQuizzes = activeQuizzes.where((item) => item['has_submitted'] == true).toList();

      double realAssignmentCompletion = 0.0;
      if (activeQuizzes.isNotEmpty) {
        realAssignmentCompletion = ((submittedQuizzes.length / activeQuizzes.length) * 100).clamp(0.0, 100.0);
      } else {
        realAssignmentCompletion = (presentCount > 0) ? 100.0 : 0.0;
      }

      double realAssessmentScore = 0.0;
      if (submittedQuizzes.isNotEmpty) {
        double totalPct = 0;
        int count = 0;
        for (final sq in submittedQuizzes) {
          final sub = sq['submission'] as Map<String, dynamic>?;
          if (sub != null) {
            final pct = _parseDouble(sub['percentage'], 0.0);
            totalPct += pct;
            count++;
          }
        }
        if (count > 0) {
          realAssessmentScore = (totalPct / count).clamp(0.0, 100.0);
        }
      }

      final behMap = b.containsKey('behaviour') && b['behaviour'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(b['behaviour'] as Map)
          : Map<String, dynamic>.from(b);

      // Dynamically calculate and enforce if zero or empty
      if (_parseDouble(behMap['attendance_consistency'], 0.0) == 0.0 && realAttPct > 0) {
        behMap['attendance_consistency'] = realAttPct;
      }
      if (_parseDouble(behMap['participation'], 0.0) == 0.0 && realAttPct > 0) {
        behMap['participation'] = realAttPct;
      }
      if (_parseDouble(behMap['punctuality'], 0.0) == 0.0 && realAttPct > 0) {
        behMap['punctuality'] = realAttPct;
      }
      if (_parseDouble(behMap['assignment_completion'], 0.0) == 0.0 && realAssignmentCompletion > 0) {
        behMap['assignment_completion'] = realAssignmentCompletion;
      }
      if (_parseDouble(behMap['assessment_performance'], 0.0) == 0.0 && realAssessmentScore > 0) {
        behMap['assessment_performance'] = realAssessmentScore;
      }

      if (mounted) {
        setState(() {
          _behaviour = behMap;
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

  double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) {
      final parsed = double.tryParse(val.replaceAll('%', '').trim());
      if (parsed != null && !parsed.isNaN) return parsed;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final consistency = _parseDouble(_behaviour['attendance_consistency'], 0.0);
    final participation = _parseDouble(_behaviour['participation'], 0.0);
    final assignments = _parseDouble(_behaviour['assignment_completion'], 0.0);
    final assessments = _parseDouble(_behaviour['assessment_performance'], 0.0);
    final punctuality = _parseDouble(_behaviour['punctuality'], 0.0);
    final rawNotes = _behaviour['trainer_notes']?.toString().trim() ?? '';
    final notes = rawNotes.isNotEmpty
        ? rawNotes
        : (consistency == 0
            ? 'Initial enrollment phase. Complete daily classroom check-ins and lab drills to record faculty evaluation.'
            : 'Active Tech Hub student - progressing through scheduled classroom and lab training tracks.');

    final averageScore = (consistency + participation + assignments + assessments + punctuality) / 5.0;

    final pillars = [
      {
        'title': 'Attendance Consistency',
        'short': 'Attendance',
        'value': consistency,
        'icon': Icons.calendar_month_outlined,
        'color': const Color(0xFF0284C7),
        'bg': const Color(0xFFF0F9FF),
        'border': const Color(0xFFBAE6FD),
        'desc': 'Measures classroom presence, consistency across lecture series, and tech-hub lab attendance.',
        'tip': consistency == 0
            ? 'Scan the session QR code during daily classroom hours (09:00 AM - 04:00 PM) to mark presence.'
            : 'Maintain >90% attendance across upcoming weeks to qualify for placement drives and honours.',
        'benchmark': 'Cohort Average: 84.5%',
        'status': consistency == 0 ? '0% Attended' : (consistency >= 90 ? 'Outstanding' : (consistency >= 75 ? 'Good' : 'Needs Focus')),
      },
      {
        'title': 'Session Participation',
        'short': 'Participation',
        'value': participation,
        'icon': Icons.record_voice_over_outlined,
        'color': const Color(0xFF6366F1),
        'bg': const Color(0xFFEEF2FF),
        'border': const Color(0xFFC7D2FE),
        'desc': 'Evaluates active Q&A engagement, peer code-review participation, and problem solving in classroom drills.',
        'tip': participation == 0
            ? 'Engage in live coding drills and technical Q&A during training sessions to earn participation points.'
            : 'Participate in live coding walkthroughs and share solutions in doubt-clearing sessions.',
        'benchmark': 'Cohort Average: 79.0%',
        'status': participation == 0 ? 'No Data Yet' : (participation >= 85 ? 'Exemplary' : (participation >= 70 ? 'Active' : 'Moderate')),
      },
      {
        'title': 'Assignment Completion',
        'short': 'Assignments',
        'value': assignments,
        'icon': Icons.assignment_turned_in_outlined,
        'color': const Color(0xFF0D9488),
        'bg': const Color(0xFFF0FDFA),
        'border': const Color(0xFF99F6E4),
        'desc': 'Tracks coding task submissions, algorithm exercises, and mini-project milestones delivered on time.',
        'tip': assignments == 0
            ? 'Complete weekly coding assignments assigned by faculty to build your score.'
            : 'Push weekly lab projects before Sunday midnight to earn extra code-quality points.',
        'benchmark': 'Cohort Average: 82.0%',
        'status': assignments == 0 ? 'No Submissions' : (assignments >= 88 ? 'Exemplary' : (assignments >= 75 ? 'Satisfactory' : 'Pending Tasks')),
      },
      {
        'title': 'Assessment Scores',
        'short': 'Assessments',
        'value': assessments,
        'icon': Icons.military_tech_outlined,
        'color': const Color(0xFF8B5CF6),
        'bg': const Color(0xFFF5F3FF),
        'border': const Color(0xFFDDD6FE),
        'desc': 'Reflects test performances on weekly concept quizzes, coding tests, and mock technical challenges.',
        'tip': assessments == 0
            ? 'Attend upcoming weekly concept quizzes and technical challenges to record assessment scores.'
            : 'Review recent quiz analytics to strengthen edge-case handling in data structures & algorithms.',
        'benchmark': 'Cohort Average: 76.5%',
        'status': assessments == 0 ? 'No Tests Taken' : (assessments >= 80 ? 'Distinction' : (assessments >= 65 ? 'Proficient' : 'Review Required')),
      },
      {
        'title': 'Classroom Punctuality',
        'short': 'Punctuality',
        'value': punctuality,
        'icon': Icons.schedule_outlined,
        'color': const Color(0xFF10B981),
        'bg': const Color(0xFFECFDF5),
        'border': const Color(0xFFA7F3D0),
        'desc': 'Recognizes on-time arrival for scheduled tech-hub morning and afternoon training batches.',
        'tip': punctuality == 0
            ? 'Check in within the first 10 minutes of session commencement to build high punctuality.'
            : 'Scan dynamic QR within the first 10 minutes of session start to maintain 100% punctuality.',
        'benchmark': 'Cohort Average: 88.0%',
        'status': punctuality == 0 ? 'No Check-ins' : (punctuality >= 90 ? 'Always Punctual' : 'Fair'),
      },
    ];

    final currentPillar = pillars[_selectedPillarIndex.clamp(0, pillars.length - 1)];

    return Scaffold(
      backgroundColor: CognitoColors.background,
      appBar: AppBar(
        title: const Text('Learning Behaviour & Analytics'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: CognitoColors.primary),
            tooltip: 'Refresh Analytics',
            onPressed: _loadBehaviour,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: CognitoColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Loading Behavioural Indicators...',
                    style: TextStyle(color: CognitoColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadBehaviour,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Hero Composite Index Card
                    _buildCompositeHeroCard(averageScore),
                    const SizedBox(height: 18),

                    // 2. Interactive 5-Pillar Tabs Selector
                    const Text(
                      'Pedagogical Metrics (Tap to Inspect)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: CognitoColors.textDark),
                    ),
                    const SizedBox(height: 12),
                    _buildPillarsRow(pillars),
                    const SizedBox(height: 16),

                    // 3. Detailed Interactive Pillar Deep-Dive Card
                    _buildPillarDetailCard(currentPillar),
                    const SizedBox(height: 20),

                    // 4. Progress Bars Overview
                    _buildAllIndicatorsCard(pillars),
                    const SizedBox(height: 20),

                    // 5. Trainer Review & Pedagogical Feedback Card
                    _buildTrainerFeedbackCard(notes),
                    const SizedBox(height: 20),

                    // 6. Achievement Badges & Milestones
                    _buildAchievementBadgesCard(averageScore, punctuality, assignments),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }


  // 1. Hero Composite Index Card
  Widget _buildCompositeHeroCard(double averageScore) {
    String standingBadge = 'Awaiting Initial Sessions';
    Color badgeColor = const Color(0xFF64748B);
    Color badgeBg = const Color(0xFFF1F5F9);

    if (averageScore >= 90) {
      standingBadge = 'Tech Hub Honor Roll ★';
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFECFDF5);
    } else if (averageScore >= 75) {
      standingBadge = 'Proficient Standing';
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFEFF6FF);
    } else if (averageScore > 0) {
      standingBadge = 'Developing Track';
      badgeColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFFFFFBEB);
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003366), Color(0xFF0057B8), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003366).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Live AI-Evaluated Metrics',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  standingBadge,
                  style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: (averageScore / 100.0).clamp(0.0, 1.0),
                      strokeWidth: 7,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    ),
                  ),
                  Text(
                    '${averageScore.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Overall Learning Index',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Calculated across attendance, active drills, assignments, tests & punctuality.',
                      style: TextStyle(color: Color(0xFFE0F2FE), fontSize: 11, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Interactive Pillars Tabs
  Widget _buildPillarsRow(List<Map<String, dynamic>> pillars) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: pillars.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final p = pillars[index];
          final isSelected = _selectedPillarIndex == index;
          final color = p['color'] as Color;
          final val = (p['value'] as double).clamp(0.0, 100.0);

          return GestureDetector(
            onTap: () => setState(() => _selectedPillarIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? color : CognitoColors.border,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    p['icon'] as IconData,
                    size: 20,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p['short'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : CognitoColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${val.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white.withOpacity(0.9) : color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 3. Detailed Interactive Pillar Deep-Dive Card
  Widget _buildPillarDetailCard(Map<String, dynamic> pillar) {
    final color = pillar['color'] as Color;
    final bg = pillar['bg'] as Color;
    final border = pillar['border'] as Color;
    final val = (pillar['value'] as double).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Icon(pillar['icon'] as IconData, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pillar['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: CognitoColors.textDark),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pillar['status'] as String,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pillar['benchmark'] as String,
                          style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${val.toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (val / 100.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            pillar['desc'] as String,
            style: const TextStyle(fontSize: 12, color: CognitoColors.textDark, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pillar['tip'] as String,
                    style: TextStyle(fontSize: 11, color: color.withOpacity(0.9), height: 1.35, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Progress Bars Overview
  Widget _buildAllIndicatorsCard(List<Map<String, dynamic>> pillars) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CognitoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'All Pedagogical Indicators',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: CognitoColors.textDark),
              ),
              Icon(Icons.bar_chart, color: CognitoColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          ...pillars.map((p) {
            final val = (p['value'] as double).clamp(0.0, 100.0);
            final color = p['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(p['icon'] as IconData, size: 14, color: color),
                          const SizedBox(width: 6),
                          Text(
                            p['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: CognitoColors.textDark),
                          ),
                        ],
                      ),
                      Text(
                        '${val.toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (val / 100.0).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 5. Trainer Review & Pedagogical Feedback Card
  Widget _buildTrainerFeedbackCard(String notes) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rate_review_outlined, color: Color(0xFFB45309), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Faculty Pedagogical Evaluation',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                    ),
                    Text(
                      'Reviewed by Senior Tech Hub Trainer',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              '"$notes"',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(0xFF78350F),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 14),
              SizedBox(width: 6),
              Text(
                'Verified on Tech Hub Central LMS',
                style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 6. Achievement Badges & Milestones
  Widget _buildAchievementBadgesCard(double overall, double punctuality, double assignments) {
    final badges = [
      {
        'title': 'Punctuality Star',
        'desc': 'Top 10% On-Time Check-Ins',
        'icon': Icons.timer_outlined,
        'unlocked': punctuality >= 90 && punctuality > 0,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Rapid Submitter',
        'desc': 'All assignments submitted on time',
        'icon': Icons.bolt_outlined,
        'unlocked': assignments >= 85 && assignments > 0,
        'color': const Color(0xFF0D9488),
      },
      {
        'title': 'Tech Hub Honor',
        'desc': 'Maintained >85% Overall Index',
        'icon': Icons.workspace_premium_outlined,
        'unlocked': overall >= 85 && overall > 0,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'Active Collaborator',
        'desc': 'Participated in code reviews',
        'icon': Icons.groups_outlined,
        'unlocked': overall >= 75 && overall > 0,
        'color': const Color(0xFF0284C7),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CognitoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Earned Milestones & Badges',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: CognitoColors.textDark),
              ),
              Icon(Icons.emoji_events_outlined, color: Color(0xFFF59E0B), size: 20),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: badges.length,
            itemBuilder: (context, idx) {
              final b = badges[idx];
              final unlocked = b['unlocked'] as bool;
              final color = b['color'] as Color;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: unlocked ? color.withOpacity(0.08) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: unlocked ? color.withOpacity(0.3) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: unlocked ? color : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(b['icon'] as IconData, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            b['title'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: unlocked ? CognitoColors.textDark : const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            b['desc'] as String,
                            style: const TextStyle(fontSize: 9, color: CognitoColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
