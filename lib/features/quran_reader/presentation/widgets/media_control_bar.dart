import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_event.dart';
import '../bloc/audio/audio_state.dart';
import 'audio_settings_sheet.dart';

class MediaControlBar extends StatefulWidget {
  const MediaControlBar({super.key});

  @override
  State<MediaControlBar> createState() => _MediaControlBarState();
}

class _MediaControlBarState extends State<MediaControlBar> {
  int? _sleepTimer;

  void _showTimerSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
        ),
        backgroundColor: const Color(0xFF8C7355),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
        duration: const Duration(seconds: 2),
        elevation: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7F0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF8C7355),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => showAudioSettingsSheet(context),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF8C7355).withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFF8C7355), size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: BlocBuilder<AudioBloc, AudioState>(
                            builder: (context, state) {
                              final currentReciter = context.read<AudioBloc>().currentReciter;
                              return Text(
                                currentReciter,
                                textAlign: TextAlign.right,
                                style: AppTextStyles.menuItemText.copyWith(
                                  color: const Color(0xFF2C2520),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Far Left: Timer and Close
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<int>(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    offset: const Offset(0, -180),
                    onSelected: (val) {
                      setState(() {
                        _sleepTimer = val == 0 ? null : val;
                      });
                      if (val == 0) {
                        context.read<AudioBloc>().add(const CancelSleepTimer());
                        _showTimerSnackBar('تم إلغاء المؤقت');
                      } else {
                        context.read<AudioBloc>().add(SetSleepTimer(Duration(minutes: val)));
                        _showTimerSnackBar('سيتم إيقاف التلاوة بعد $val دقائق');
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 0, child: Align(alignment: Alignment.centerRight, child: Text('إيقاف المؤقت', textDirection: TextDirection.rtl))),
                      const PopupMenuItem(value: 5, child: Align(alignment: Alignment.centerRight, child: Text('5 دقائق', textDirection: TextDirection.rtl))),
                      const PopupMenuItem(value: 10, child: Align(alignment: Alignment.centerRight, child: Text('10 دقائق', textDirection: TextDirection.rtl))),
                      const PopupMenuItem(value: 15, child: Align(alignment: Alignment.centerRight, child: Text('15 دقيقة', textDirection: TextDirection.rtl))),
                      const PopupMenuItem(value: 30, child: Align(alignment: Alignment.centerRight, child: Text('30 دقيقة', textDirection: TextDirection.rtl))),
                      const PopupMenuItem(value: 60, child: Align(alignment: Alignment.centerRight, child: Text('60 دقيقة', textDirection: TextDirection.rtl))),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: _sleepTimer != null ? const Color(0xFFB48A5E) : const Color(0xFF2C2520),
                            size: 24,
                          ),
                          if (_sleepTimer != null)
                            Text(
                              '${_sleepTimer}m',
                              style: const TextStyle(fontSize: 10, color: Color(0xFFB48A5E), fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      context.read<AudioBloc>().add(const StopAudio());
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Color(0xFF2C2520), size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom Row Playback Controls
          BlocBuilder<AudioBloc, AudioState>(
            builder: (context, state) {
              final isPlaying = state is AudioPlaying;
              final isLoading = state is AudioLoading;
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 32),
                  // Center Playback Controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, color: Color(0xFF2C2520), size: 32),
                        onPressed: () {
                          // Previous track functionality
                        },
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          if (isPlaying) {
                            context.read<AudioBloc>().add(const PauseAudio());
                          } else {
                            context.read<AudioBloc>().add(const ResumeAudio());
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB48A5E), // Solid brown circle
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, color: Color(0xFF2C2520), size: 32),
                        onPressed: () {
                          // Next track functionality
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
