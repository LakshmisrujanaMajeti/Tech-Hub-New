import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'quiz_result_screen.dart';

class TakeQuizScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const TakeQuizScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<TakeQuizScreen> createState() => _TakeQuizScreenState();
}

class _TakeQuizScreenState extends State<TakeQuizScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _quizData;
  List<dynamic> _questions = [];

  int _currentQuestionIndex = 0;
  final Map<String, String> _selectedAnswers = {}; // question_id -> option_id
  final Set<String> _markedForReview = {};

  // Tab switch violation tracking
  int _tabSwitchCount = 0;
  bool _isWarningDialogShowing = false;

  // Exam Countdown Timer
  Timer? _countdownTimer;
  int _secondsRemaining = 15 * 60;
  int _totalDurationSeconds = 15 * 60;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadQuiz();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _handleTabSwitchViolation();
    }
  }

  void _handleTabSwitchViolation() {
    if (_isLoading || _isSubmitting || _quizData == null) return;
    if (_isWarningDialogShowing) return;

    _tabSwitchCount++;

    // Sync progress and tab switch count to backend immediately
    ApiService.saveQuizProgress(
      quizId: widget.quizId,
      answers: _selectedAnswers,
      tabSwitchCount: _tabSwitchCount,
    );

    if (_tabSwitchCount == 1) {
      _showTabSwitchWarning(
        title: '⚠️ Tab Switch Warning (1 of 2)',
        message: 'Switching tabs, minimizing the screen, or leaving the exam screen is strictly prohibited.\n\n⚠️ Warning 1 of 2: You have 1 warning remaining. If you switch tabs 2 more times, your exam will be automatically closed and submitted immediately with NO REATTEMPT allowed.',
        buttonText: 'Return to Exam',
        badgeColor: const Color(0xFFD97706),
        isFinal: false,
      );
    } else if (_tabSwitchCount == 2) {
      _showTabSwitchWarning(
        title: '🚨 FINAL WARNING: Tab Switch (2 of 2)',
        message: 'You have switched tabs / left the exam 2 times!\n\n⛔ If you switch tabs or leave this window ONE MORE TIME, your exam will be immediately TERMINATED and submitted. Reattempts are strictly forbidden.',
        buttonText: 'I Acknowledge - Continue Exam',
        badgeColor: const Color(0xFFDC2626),
        isFinal: true,
      );
    } else if (_tabSwitchCount >= 3) {
      _handleAutoSubmitOnTabLimit();
    }
  }

  Future<void> _showTabSwitchWarning({
    required String title,
    required String message,
    required String buttonText,
    required Color badgeColor,
    required bool isFinal,
  }) async {
    _isWarningDialogShowing = true;
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isFinal ? Icons.report_problem_rounded : Icons.warning_amber_rounded,
                color: badgeColor,
                size: 26,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: CognitoColors.textDark),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: badgeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
    _isWarningDialogShowing = false;
  }

  Future<void> _handleAutoSubmitOnTabLimit() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    _countdownTimer?.cancel();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFFDC2626), size: 26),
              SizedBox(width: 8),
              Text('Exam Terminated', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 50),
              SizedBox(height: 12),
              Text(
                'Tab Switch Limit Exceeded (3/3)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CognitoColors.textDark),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'You switched tabs / left the exam screen 3 times. As per anti-cheating regulations, your test has been automatically closed and submitted. Reattempts are not allowed.',
                style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(color: CognitoColors.danger, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );

    await _performSubmission(
      isAutoSubmitted: true,
      submissionReason: 'TERMINATED_TAB_SWITCH_LIMIT_EXCEEDED',
    );
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getQuizDetails(widget.quizId);
      if (!mounted) return;

      if (res['is_completed'] == true || res['has_submitted'] == true) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'You have already completed and submitted this test.\nStrictly 1 attempt only is permitted.';
        });
        return;
      }

      final quiz = res['quiz'] as Map<String, dynamic>?;
      if (quiz == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Quiz details could not be loaded.';
        });
        return;
      }

      final rawQuestions = (quiz['questions'] as List<dynamic>?) ?? [];
      final durationMins = quiz['duration_minutes'] ?? 15;
      final durationSecs = durationMins * 60;

      // 1. Jumble/Randomize questions uniquely for each student attempt
      // 2. Jumble/Randomize options uniquely for each student to prevent copying/cheating.
      final displayLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
      final shuffledRawQuestions = List<dynamic>.from(rawQuestions)..shuffle();
      final processedQuestions = <dynamic>[];

      for (int qIdx = 0; qIdx < shuffledRawQuestions.length; qIdx++) {
        final qItem = shuffledRawQuestions[qIdx];
        if (qItem is Map) {
          final qMap = Map<String, dynamic>.from(qItem);
          final rawOptions = (qMap['options'] as List<dynamic>?) ?? [];

          if (rawOptions.isNotEmpty) {
            // Shuffle a mutable copy of options uniquely
            final shuffledOptions = List<dynamic>.from(rawOptions)..shuffle();
            final randomizedOptions = <Map<String, dynamic>>[];

            for (int optIdx = 0; optIdx < shuffledOptions.length; optIdx++) {
              final rawOpt = shuffledOptions[optIdx];
              if (rawOpt is Map) {
                final origId = (rawOpt['original_id'] ?? rawOpt['id'] ?? rawOpt['key'] ?? displayLetters[optIdx % displayLetters.length]).toString();
                final optText = (rawOpt['text'] ?? rawOpt['option_text'] ?? rawOpt['value'] ?? '').toString();
                final displayLabel = optIdx < displayLetters.length ? displayLetters[optIdx] : '${optIdx + 1}';

                randomizedOptions.add({
                  'id': origId, // Preserves the original option ID ('A', 'B', 'C', 'D') for 100% accurate grading
                  'original_id': origId,
                  'display_label': displayLabel, // The sequential option letter shown to this student
                  'text': optText,
                });
              }
            }
            qMap['options'] = randomizedOptions;
          }
          processedQuestions.add(qMap);
        } else {
          processedQuestions.add(qItem);
        }
      }

      setState(() {
        _quizData = quiz;
        _questions = processedQuestions;
        _totalDurationSeconds = durationSecs;
        _secondsRemaining = durationSecs;
        _isLoading = false;
      });

      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        // Time is UP!
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
        _handleAutoSubmitOnTimeout();
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleAutoSubmitOnTimeout() async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    // Show Auto-Submit Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_off_rounded, color: Color(0xFFDC2626), size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Time is Up!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'The allocated quiz time has elapsed. Your marked answers are being submitted automatically...',
                style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: CognitoColors.primary, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );

    await _performSubmission(isAutoSubmitted: true, submissionReason: 'TIMEOUT');
  }

  Future<void> _handleManualSubmit() async {
    final unansweredCount = _questions.length - _selectedAnswers.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: CognitoColors.primary),
            SizedBox(width: 8),
            Text('Submit Test'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to submit the test?\nYou can attempt this test only once.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'You have answered ${_selectedAnswers.length} of ${_questions.length} questions.',
              style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
            ),
            if (unansweredCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '⚠️ $unansweredCount question(s) remain unanswered.',
                style: const TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Time Remaining: ${_formatTimer(_secondsRemaining)}',
              style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Submit Test'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _countdownTimer?.cancel();
    setState(() => _isSubmitting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: CognitoColors.primary),
        ),
      ),
    );

    await _performSubmission(isAutoSubmitted: false, submissionReason: 'NORMAL');
  }

  Future<void> _performSubmission({
    required bool isAutoSubmitted,
    String? submissionReason,
  }) async {
    final timeTaken = _totalDurationSeconds - _secondsRemaining;

    try {
      final res = await ApiService.submitQuiz(
        quizId: widget.quizId,
        answers: _selectedAnswers,
        timeTakenSeconds: MathMax(1, timeTaken),
        isAutoSubmitted: isAutoSubmitted,
        submissionReason: submissionReason,
        tabSwitchCount: _tabSwitchCount,
      );

      if (!mounted) return;

      // Close loading/timeout dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Navigate to Submission Confirmation Screen (no answers or score leaked)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            quizTitle: widget.quizTitle,
            submission: {
              'time_taken_seconds': timeTaken,
              'is_auto_submitted': isAutoSubmitted,
              'submission_reason': submissionReason ?? (isAutoSubmitted ? 'TIMEOUT' : 'NORMAL'),
              'tab_switch_count': _tabSwitchCount,
              'submitted_at': DateTime.now().toIso8601String(),
              'message': res['message'] ?? 'Test Submitted Successfully',
            },
            isReviewMode: false,
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission Error: ${err.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: CognitoColors.danger,
        ),
      );
    }
  }

  int MathMax(int a, int b) => a > b ? a : b;

  void _openGoogleForm(String url) async {
    final cleanUrl = url.trim().startsWith('http://') || url.trim().startsWith('https://')
        ? url.trim()
        : 'https://${url.trim()}';
    final uri = Uri.parse(cleanUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open external form link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(widget.quizTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0.5,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: CognitoColors.primary),
              SizedBox(height: 16),
              Text('Preparing your randomized question paper...', style: TextStyle(color: CognitoColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Assessment'),
          backgroundColor: Colors.white,
          elevation: 0.5,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: CognitoColors.danger, size: 48),
                const SizedBox(height: 12),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Return to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isGoogleForm = _quizData?['quiz_type'] == 'GOOGLE_FORM';
    if (isGoogleForm) {
      return _buildGoogleFormView();
    }

    final isLowTime = _secondsRemaining < 120; // < 2 minutes
    final progress = _totalDurationSeconds > 0 ? (_secondsRemaining / _totalDurationSeconds).clamp(0.0, 1.0) : 0.0;
    final currentQ = _questions.isNotEmpty ? _questions[_currentQuestionIndex] as Map<String, dynamic> : null;
    final currentQId = currentQ?['id']?.toString() ?? '';
    final selectedOption = _selectedAnswers[currentQId];
    final isMarked = _markedForReview.contains(currentQId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmExitExam();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            tooltip: 'Exit Test',
            onPressed: _confirmExitExam,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.quizTitle,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${_quizData?['course_name'] ?? 'Technical Test'} • ${_questions.length} Questions',
                style: const TextStyle(fontSize: 10, color: CognitoColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            // Tab Switch Violation Counter Badge
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _tabSwitchCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _tabSwitchCount > 0 ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tab_unselected_rounded,
                    size: 13,
                    color: _tabSwitchCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tab Switches: $_tabSwitchCount/2',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _tabSwitchCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),

            // Fixed Live Countdown Timer Badge
            Container(
              margin: const EdgeInsets.only(left: 4, right: 12, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isLowTime ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLowTime ? const Color(0xFFEF4444) : const Color(0xFF93C5FD),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: isLowTime ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimer(_secondsRemaining),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isLowTime ? const Color(0xFFDC2626) : const Color(0xFF1E40AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isLowTime ? const Color(0xFFDC2626) : CognitoColors.primary,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Question Palette Bar
            _buildQuestionPalette(),

            // Main Question Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: currentQ == null
                    ? const Center(child: Text('No questions available.'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question Header Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
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
                                        color: CognitoColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: CognitoColors.primary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: Text(
                                        '+${currentQ['marks'] ?? 1} Marks',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  currentQ['question_text'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: CognitoColors.textDark,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Option Choices (A, B, C, D)
                          const Text(
                            'SELECT ONE OPTION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: CognitoColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),

                          ...((currentQ['options'] as List<dynamic>?) ?? []).map((opt) {
                            final optMap = opt is Map<String, dynamic> ? opt : Map<String, dynamic>.from(opt as Map);
                            final origOptId = (optMap['original_id'] ?? optMap['id'] ?? '').toString();
                            final displayLabel = (optMap['display_label'] ?? optMap['id'] ?? '').toString();
                            final optText = (optMap['text'] ?? '').toString();
                            final isSelected = selectedOption == origOptId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? CognitoColors.primary : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: CognitoColors.primary.withOpacity(0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    setState(() {
                                      _selectedAnswers[currentQId] = origOptId;
                                    });
                                    ApiService.saveQuizProgress(
                                      quizId: widget.quizId,
                                      answers: _selectedAnswers,
                                      tabSwitchCount: _tabSwitchCount,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isSelected ? CognitoColors.primary : Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? CognitoColors.primary : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              displayLabel,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                color: isSelected ? Colors.white : CognitoColors.textDark,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            optText,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              color: isSelected ? CognitoColors.primary : CognitoColors.textDark,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle_rounded, color: CognitoColors.primary, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ),

            // Bottom Navigation Footer Controls
            _buildBottomActionBar(currentQId, isMarked),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPalette() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_questions.length, (idx) {
            final q = _questions[idx];
            final qId = q['id']?.toString() ?? '';
            final isCur = idx == _currentQuestionIndex;
            final isAnswered = _selectedAnswers.containsKey(qId);
            final isReview = _markedForReview.contains(qId);

            Color bgColor = Colors.grey.shade100;
            Color textColor = Colors.black87;
            Color borderColor = Colors.grey.shade300;

            if (isCur) {
              borderColor = CognitoColors.primary;
            }

            if (isAnswered) {
              bgColor = const Color(0xFF16A34A);
              textColor = Colors.white;
              borderColor = const Color(0xFF16A34A);
            } else if (isReview) {
              bgColor = const Color(0xFFD97706);
              textColor = Colors.white;
              borderColor = const Color(0xFFD97706);
            }

            return GestureDetector(
              onTap: () => setState(() => _currentQuestionIndex = idx),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: isCur ? 2 : 1),
                  boxShadow: [
                    if (isCur)
                      BoxShadow(
                        color: CognitoColors.primary.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${idx + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCur ? FontWeight.w900 : FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(String currentQId, bool isMarked) {
    final hasPrev = _currentQuestionIndex > 0;
    final hasNext = _currentQuestionIndex < _questions.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Mark for Review toggle
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  if (isMarked) {
                    _markedForReview.remove(currentQId);
                  } else {
                    _markedForReview.add(currentQId);
                  }
                });
              },
              icon: Icon(
                isMarked ? Icons.bookmark_remove_rounded : Icons.bookmark_border_rounded,
                size: 16,
                color: isMarked ? const Color(0xFFD97706) : Colors.grey.shade600,
              ),
              label: Text(
                isMarked ? 'Unmark' : 'Review Later',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isMarked ? const Color(0xFFD97706) : Colors.grey.shade700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                side: BorderSide(color: isMarked ? const Color(0xFFD97706) : Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),

            // Prev Button
            if (hasPrev)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => setState(() => _currentQuestionIndex--),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            const SizedBox(width: 6),

            // Next or Submit
            Expanded(
              child: hasNext
                  ? ElevatedButton.icon(
                      onPressed: () => setState(() => _currentQuestionIndex++),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Next Question', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CognitoColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _handleManualSubmit,
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Submit Quiz', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleFormView() {
    final formUrl = _quizData?['google_form_url'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.quizTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_rounded, color: Color(0xFF7C3AED), size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.quizTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _quizData?['description'] ?? 'Please complete this test using the external Google Form link provided below.',
                    style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => _openGoogleForm(formUrl),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: const Text('Open Google Form Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _performSubmission(isAutoSubmitted: false),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('I Have Completed The Google Form', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExitExam() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: CognitoColors.danger, size: 24),
            SizedBox(width: 8),
            Text('Exit & Submit Exam?'),
          ],
        ),
        content: const Text(
          'Exiting the exam now will immediately SUBMIT your test and mark it as completed.\n\nStrict 1-Attempt Rule: You will NOT be allowed to re-enter or reattempt this test.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay in Test'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CognitoColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Submit & Exit'),
          ),
        ],
      ),
    );

    if (exit == true && mounted) {
      await _performSubmission(
        isAutoSubmitted: true,
        submissionReason: 'TERMINATED_UNEXPECTED_WINDOW_CLOSE',
      );
    }
  }
}
