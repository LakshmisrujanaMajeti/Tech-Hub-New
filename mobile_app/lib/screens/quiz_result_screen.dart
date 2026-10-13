import 'package:flutter/material.dart';
import '../core/theme.dart';

class QuizResultScreen extends StatelessWidget {
  final String quizTitle;
  final Map<String, dynamic> submission;
  final List<dynamic>? reviewData;
  final bool isReviewMode;

  const QuizResultScreen({
    super.key,
    required this.quizTitle,
    required this.submission,
    this.reviewData,
    this.isReviewMode = false,
  });

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '$minutes min ${seconds > 0 ? '$seconds sec' : ''}';
    }
    return '$seconds sec';
  }

  @override
  Widget build(BuildContext context) {
    final timeTaken = submission['time_taken_seconds'] ?? 0;
    final isAutoSubmitted = submission['is_auto_submitted'] == true;
    final submittedAt = submission['submitted_at']?.toString() ?? '';

    final reviewList = reviewData ?? [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          automaticallyImplyLeading: isReviewMode,
          title: Text(
            isReviewMode ? 'Assessment Review' : 'Test Submission',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Confirmation Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Success Badge Icon
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 46,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        const Text(
                          'Test Submitted Successfully',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: CognitoColors.textDark,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),

                        // Subtitle
                        const Text(
                          'You have successfully submitted your test.\nYour result will be available through your trainer/portal.',
                          style: TextStyle(
                            fontSize: 13,
                            color: CognitoColors.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Test Details Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.assignment_outlined, size: 16, color: CognitoColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      quizTitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: CognitoColors.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              _buildDetailRow(
                                icon: Icons.access_time_rounded,
                                label: 'Time Spent',
                                value: _formatTime(timeTaken),
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                icon: Icons.send_rounded,
                                label: 'Submission Mode',
                                value: isAutoSubmitted ? 'Auto-Submitted (Time Out)' : 'Manual Submission',
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                icon: Icons.verified_user_rounded,
                                label: 'Attempt Status',
                                value: 'Submitted & Recorded',
                                valueColor: const Color(0xFF16A34A),
                              ),
                              if (submittedAt.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  icon: Icons.calendar_today_rounded,
                                  label: 'Submission Timestamp',
                                  value: submittedAt.length > 19
                                      ? submittedAt.substring(0, 19).replaceAll('T', ' ')
                                      : submittedAt,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Security notice
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 18, color: Color(0xFFB45309)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'One-Attempt Rule: This test is permanently marked as completed. Reattempting or modifying answers is not allowed.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Back to Dashboard Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: const Text(
                              'Back to Dashboard',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CognitoColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // If Review Mode is active and review data is provided (for trainer viewing)
                  if (isReviewMode && reviewList.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'QUESTION BREAKDOWN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: CognitoColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...reviewList.map((item) {
                      final qText = item['question_text'] ?? '';
                      final studentAns = item['student_answer'] ?? 'NOT_ATTEMPTED';
                      final correctOpt = item['correct_option'] ?? '';
                      final isCorr = item['is_correct'] == true;
                      final explanation = item['explanation'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCorr ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isCorr ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCorr ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    color: isCorr ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    qText,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'Your Answer: ',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  studentAns,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCorr ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                if (!isCorr) ...[
                                  Text(
                                    'Correct Answer: ',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    correctOpt,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                  ),
                                ],
                              ],
                            ),
                            if (explanation.toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFFD97706)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        explanation,
                                        style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor ?? CognitoColors.textDark,
          ),
        ),
      ],
    );
  }
}
