import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../voice/voice_state.dart';
import 'chat_controller.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/atmospheric_background.dart';
import 'widgets/luminous_orb.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final input = TextEditingController();
  final recorder = AudioRecorder();
  final player = AudioPlayer();
  final scroll = ScrollController();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  VoiceState voice = const VoiceState();
  Timer? timer;
  CancelToken? upload;
  String? recordingPath, playbackPath, error, playing;
  bool speech = true;
  bool starting = false;
  int seconds = 0;
  int voiceGeneration = 0;

  @override
  void initState() {
    super.initState();
    loadPreferences();
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() => playing = null);
      }
    });
  }

  Future<void> loadPreferences() async {
    try {
      final data = await ref.read(apiProvider).get('/memory/preferences');
      if (mounted) {
        ref.read(scriptProvider.notifier).select(data['script'] ?? 'arabic');
      }
    } catch (_) {
      /* Chat remains usable if preferences are offline. */
    }
  }

  Future<void> removeFile(String? path) async {
    if (path == null) {
      return;
    }
    final file = File(path);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      /* Cleanup can race with cancellation. */
    }
  }

  Future<void> microphone() async {
    if (voice.phase == VoicePhase.recording) {
      await stop();
      return;
    }
    if (starting ||
        voice.phase != VoicePhase.idle ||
        ref.read(chatProvider).busy) {
      return;
    }
    starting = true;
    final generation = ++voiceGeneration;
    try {
      if (!await recorder.hasPermission()) {
        throw StateError('خاصنا الإذن باش نستعملو الميكروفون');
      }
      await player.stop();
      final directory = await getTemporaryDirectory();
      recordingPath =
          '${directory.path}/voice-${DateTime.now().microsecondsSinceEpoch}.wav';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: recordingPath!,
      );
      if (!mounted || generation != voiceGeneration) {
        await recorder.cancel();
        return;
      }
      setState(() {
        voice = voice.start();
        seconds = 0;
        error = null;
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() => seconds++);
        if (seconds >= 60) {
          timer?.cancel();
          unawaited(stop());
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error = e is StateError ? e.message.toString() : friendlyError(e),
        );
      }
      await removeFile(recordingPath);
    } finally {
      starting = false;
    }
  }

  Future<void> stop() async {
    if (voice.phase != VoicePhase.recording) {
      return;
    }
    timer?.cancel();
    final generation = voiceGeneration;
    final pathToDelete = recordingPath;
    setState(() => voice = voice.stop());
    try {
      final path = await recorder.stop();
      if (path == null) {
        throw StateError('No recording');
      }
      upload = CancelToken();
      final data = await ref.read(apiProvider).post(
            '/speech/transcribe',
            FormData.fromMap({
              'file': await MultipartFile.fromFile(
                path,
                filename: 'recording.wav',
                contentType: DioMediaType('audio', 'wav'),
              ),
            }),
            upload,
          );
      if (!mounted || generation != voiceGeneration) {
        return;
      }
      setState(() {
        voice = voice.preview(data['text']);
        input.text = data['text'];
      });
    } catch (e) {
      if (mounted && generation == voiceGeneration) {
        setState(() {
          voice = voice.reset();
          error = friendlyError(e);
        });
      }
    } finally {
      await removeFile(pathToDelete);
    }
  }

  Future<void> cancelVoice() async {
    if (voice.phase == VoicePhase.preview) {
      input.clear();
    }
    voiceGeneration++;
    timer?.cancel();
    upload?.cancel();
    await recorder.cancel();
    await removeFile(recordingPath);
    if (mounted) {
      setState(() {
        voice = voice.reset();
        error = null;
      });
    }
  }

  Future<void> send([String? retry]) async {
    final text = retry ?? input.text;
    if (text.trim().isEmpty) {
      return;
    }
    input.clear();
    setState(() {
      voice = voice.reset();
      error = null;
    });
    await ref
        .read(chatProvider.notifier)
        .send(text, speech: speech, script: ref.read(scriptProvider));
    if (mounted && scroll.hasClients) {
      await scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> play(ChatMessage message) async {
    try {
      if (playing == message.text && player.playing) {
        await player.pause();
        setState(() => playing = null);
        return;
      }
      await player.stop();
      await removeFile(playbackPath);
      final directory = await getTemporaryDirectory();
      playbackPath =
          '${directory.path}/answer-${DateTime.now().microsecondsSinceEpoch}.mp3';
      await File(playbackPath!).writeAsBytes(message.audio!);
      await player.setFilePath(playbackPath!);
      if (mounted) {
        setState(() => playing = message.text);
      }
      unawaited(player.play());
    } catch (e) {
      if (mounted) {
        setState(() => error = 'تعذر تشغيل الصوت');
      }
    }
  }

  @override
  void dispose() {
    voiceGeneration++;
    timer?.cancel();
    upload?.cancel();
    unawaited(recorder.dispose());
    unawaited(player.dispose());
    unawaited(removeFile(recordingPath));
    unawaited(removeFile(playbackPath));
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTranscribing = voice.phase == VoicePhase.transcribing;

    ref.listen(chatProvider, (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0) &&
          speech &&
          next.messages.last.audio != null) {
        unawaited(play(next.messages.last));
      }
    });

    return Scaffold(
      key: scaffoldKey,
      drawer: Drawer(
        child: AppSidebar(
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
      body: AtmosphericBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 840;
              return Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1360),
                  margin: EdgeInsets.symmetric(
                    horizontal: isWide ? 20 : 0,
                    vertical: isWide ? 16 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(isWide ? 28 : 0),
                    boxShadow: isWide
                        ? [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                              blurRadius: 36,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : null,
                    border: isWide
                        ? Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : const Color(0xFFEDE8F6),
                            width: 1.2,
                          )
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      // Sidebar for Desktop/Tablet
                      if (isWide) const AppSidebar(),

                      // Main Content Area
                      Expanded(
                        child: Column(
                          children: [
                            // 1. Top Header Bar (Model Pill, Export, Upgrade/Beta)
                            _buildTopBar(context, isWide, state),

                            // Mock Data Notice Banner
                            _buildMockNotice(),

                            // 2. Middle Body: Welcome Hero OR Active Chat Messages
                            Expanded(
                              child: state.messages.isEmpty
                                  ? _buildWelcomeHero(context, state)
                                  : _buildMessagesList(state),
                            ),

                            // Status / Progress / Error Indicators
                            if (state.busy || isTranscribing)
                              const LinearProgressIndicator(minHeight: 2),
                            if (state.busy || isTranscribing)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  isTranscribing
                                      ? 'كنحولو الصوت للنص…'
                                      : 'كنوجدو الجواب…',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textViolet,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if ((error ?? state.error) != null)
                              _buildErrorBanner(state),

                            if (voice.phase == VoicePhase.preview)
                              _buildPreviewNotice(),

                            // 3. Prompt Box Area (Fixed at bottom when chat is active, or already shown in hero)
                            if (state.messages.isNotEmpty)
                              _buildBottomInputBar(state),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    bool isWide,
    ChatState state,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFF0ECF6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Sidebar menu trigger for phones
          if (!isWide)
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 22),
              tooltip: 'القائمة',
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
            ),

          // Model Selector Pill (like "Cortex ▾")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF221F32) : const Color(0xFFF7F5FB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFEBE6F3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 15,
                  color: AppColors.primary,
                ),
                SizedBox(width: 7),
                Text(
                  'الحريفي AI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),

          const Spacer(),

          // Audio Mute/Unmute Toggle
          IconButton(
            tooltip: speech ? 'صوت الجواب: شغال' : 'صوت الجواب: مطفي',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => speech = !speech),
            icon: Icon(
              speech ? Icons.volume_up_outlined : Icons.volume_off_outlined,
              size: 20,
              color: speech ? AppColors.primary : AppColors.textMuted,
            ),
          ),

          // New chat icon (quick access)
          IconButton(
            tooltip: 'محادثة جديدة',
            visualDensity: VisualDensity.compact,
            onPressed: state.busy
                ? null
                : () {
                    ref.read(chatProvider.notifier).fresh();
                  },
            icon: const Icon(Icons.add_comment_outlined, size: 20),
          ),

          // Export Chat Pill Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              side: BorderSide(
                color: isDark ? AppColors.borderDark : const Color(0xFFE0DAEC),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('يمكنك نسخ المحادثة أو تصديرها من الإعدادات'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.file_upload_outlined, size: 16),
            label: const Text(
              'تصدير المحادثة',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),

          const SizedBox(width: 8),

          // Upgrade / Beta Black Pill Button
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E2943) : AppColors.darkPill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/settings'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Text(
                    'النسخة الكاملة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockNotice() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F3FD),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: const Text(
        'نسخة تجريبية • معلومات الحرفة أمثلة فقط • خصوصية كاملة',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: Color(0xFF7A6B97),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildWelcomeHero(BuildContext context, ChatState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // 1. The Luminous 3D Purple Orb
              const LuminousOrb(size: 110),

              const SizedBox(height: 20),

              // 2. Warm Personal Greeting
              const Text(
                'السلام عليكم، الحريفي',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'كيفاش نقدر نعاونك اليوم؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 28),

              // 3. The Main Prompt Card (matching Cortex Prompt Box)
              _buildPromptCard(context, state),

              const SizedBox(height: 24),

              // 4. Quick Action Cards (3 cards below input)
              _buildQuickActionCards(state),

              const SizedBox(height: 36),

              // 5. Community & Help Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard(BuildContext context, ChatState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRecording = voice.phase == VoicePhase.recording;
    final isTranscribing = voice.phase == VoicePhase.transcribing;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1C2B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE8E2F2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Text Input Field
          TextField(
            controller: input,
            minLines: 1,
            maxLines: 4,
            maxLength: 4000,
            enabled: !state.busy && !isRecording && !isTranscribing,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'سولني على أي حاجة فخدمتك أو طلب مساعدة…',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : AppColors.textMuted,
              ),
              counterText: '',
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
            onSubmitted: (_) => send(),
          ),

          const SizedBox(height: 12),

          // Inner Bottom Controls Row
          Row(
            children: [
              // Left: "بحث متقدم" ("Deeper Research" pill)
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2343)
                      : const Color(0xFFF6F2FE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF4C3E75)
                        : const Color(0xFFDDD0FA),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        input.text =
                            'عطيني خطة عملية ومفصلة باش نطور الخدمة ديالي: ';
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'بحث متقدم',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Lightbulb quick tip icon
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'فكرة سريعة',
                icon: const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                onPressed: () {
                  setState(() {
                    input.text = 'عطيني فكرة لمنشور يجيب ليا كليان جداد';
                  });
                },
              ),

              const Spacer(),

              // Quick Actions on Right (Photos, Web, Mic)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'إضافة صورة لخدمتك',
                icon: const Icon(
                  Icons.image_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تحليل الصور كيتفعل مع توفر الخدمة'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'استكشاف الأفكار',
                icon: const Icon(
                  Icons.language_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                onPressed: () => context.push('/business'),
              ),

              const SizedBox(width: 4),

              // Glowing Circular Voice Button (Mic)
              _buildGlowingMicButton(state),
            ],
          ),

          const SizedBox(height: 10),

          // Underneath Row: "+ أفكار مسجلة" and "إرفاق ملف"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                onPressed: () => context.push('/business'),
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const Text(
                  '+ أفكار مسجلة',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : const Color(0xFFDDD8E8),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => context.push('/business'),
                icon: const Icon(Icons.attach_file_rounded, size: 15),
                label: const Text(
                  'إرفاق ملف',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingMicButton(ChatState state) {
    final isRecording = voice.phase == VoicePhase.recording;
    final isTranscribing = voice.phase == VoicePhase.transcribing;
    final isBusy = state.busy || isTranscribing || voice.phase == VoicePhase.preview;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isRecording
              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
              : [const Color(0xFF9333EA), const Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isRecording ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6))
                .withValues(alpha: 0.42),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: isBusy ? null : microphone,
          child: Center(
            child: isRecording
                ? Text(
                    '$seconds',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCards(ChatState state) {
    final suggestions = [
      (
        icon: Icons.pie_chart_outline_rounded,
        title: 'تلخيص ومعلومات',
        subtitle: 'لخص نقط مهمة فخدمتك فـ 5 نقط واضحة',
        prompt: 'عاونّي نلخص أهم النقط فخدمتي باش نقدمها للكليان بكل وضوح',
      ),
      (
        icon: Icons.lightbulb_outline_rounded,
        title: 'عصف ذهني إبداعي',
        subtitle: 'اقترح أفكار مبتكرة لفيديو كيروج لخدمتك',
        prompt: 'اقترح عليا 3 أفكار مبتكرة لفيديوهات تيكتوك وريلز على خدمتي',
      ),
      (
        icon: Icons.fact_check_outlined,
        title: 'استشارة وحساب الثمن',
        subtitle: 'كيفاش تحسب الدوفي والتكلفة بلا ما تخسر',
        prompt: 'كيفاش نحسب ثمن الخدمة والدوفي بشكل احترافي بلا ما نخسر؟',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 620;
        if (isSmall) {
          return Column(
            children: [
              for (final item in suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SuggestionCard(
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    onTap: () {
                      setState(() => input.text = item.prompt);
                    },
                  ),
                ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < suggestions.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _SuggestionCard(
                  icon: suggestions[i].icon,
                  title: suggestions[i].title,
                  subtitle: suggestions[i].subtitle,
                  onTap: () {
                    setState(() => input.text = suggestions[i].prompt);
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'مجتمع الحريفي لتبادل الخبرات • نسخة تجريبية',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 14),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.translate, size: 16, color: AppColors.textMuted),
          tooltip: 'اللغة: الدارجة المغربية',
          onPressed: () {},
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.help_outline_rounded,
              size: 16, color: AppColors.textMuted),
          tooltip: 'مساعدة واستفسارات',
          onPressed: () => context.push('/business'),
        ),
      ],
    );
  }

  Widget _buildMessagesList(ChatState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(20),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        final isUser = message.role == 'user';

        return Align(
          alignment: isUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUser
                  ? (isDark
                      ? const Color(0xFF2D234A)
                      : const Color(0xFFF3EDFD))
                  : (isDark
                      ? const Color(0xFF1E1B2B)
                      : Colors.white),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isUser
                    ? const Color(0xFFDCCDF9)
                    : (isDark ? AppColors.borderDark : const Color(0xFFEDE8F4)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isUser
                            ? AppColors.primary
                            : const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        isUser ? Icons.person : Icons.auto_awesome,
                        size: 13,
                        color: isUser ? Colors.white : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUser ? 'أنت' : 'الحريفي AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isUser ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  message.text,
                  style: const TextStyle(fontSize: 14.5, height: 1.5),
                ),
                if (message.audio != null) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => play(message),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDECFF8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            playing == message.text
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            playing == message.text
                                ? 'وقف الصوت'
                                : 'استمع للجواب الصوتي',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomInputBar(ChatState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRecording = voice.phase == VoicePhase.recording;
    final isTranscribing = voice.phase == VoicePhase.transcribing;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFF0ECF6),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF221F31) : const Color(0xFFF7F5FA),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : const Color(0xFFEBE6F3),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 4000,
                      enabled: !state.busy && !isRecording && !isTranscribing,
                      decoration: const InputDecoration(
                        hintText: 'كتب الرسالة ديالك…',
                        counterText: '',
                        isDense: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => send(),
                    ),
                  ),
                  if (voice.phase != VoicePhase.idle)
                    IconButton(
                      tooltip: 'إلغاء التسجيل',
                      onPressed: cancelVoice,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  _buildGlowingMicButton(state),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: IconButton(
              tooltip: 'إرسال',
              onPressed: state.busy || isRecording || isTranscribing
                  ? null
                  : () => send(),
              icon: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ChatState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              error ?? state.error!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (state.retryText != null)
            TextButton(
              onPressed: state.busy ? null : () => send(state.retryText),
              child: const Text('إعادة المحاولة'),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewNotice() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F3FE),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            'راجع النص وصححو قبل ما تصيفطو',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1C2B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFEBE6F3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
