import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_event.dart';
import '../bloc/audio/audio_state.dart';
import '../../../../core/network/audio_download_manager.dart';

class MediaControlBar extends StatelessWidget {
  const MediaControlBar({super.key});

  void _showReciterSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFBF7F0), // Soft cream
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 20.0),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'اختر القارئ',
                style: AppTextStyles.headerText.copyWith(color: AppColors.accentGold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: AudioDownloadManager.reciterCategories.length,
                  itemBuilder: (context, index) {
                    final categoryEntry = AudioDownloadManager.reciterCategories.entries.elementAt(index);
                    final categoryName = categoryEntry.key;
                    final reciters = categoryEntry.value.keys.toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            categoryName,
                            style: AppTextStyles.menuItemText.copyWith(
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        ...reciters.map((reciter) {
                          return BlocBuilder<AudioBloc, AudioState>(
                            builder: (context, state) {
                              final currentReciter = context.read<AudioBloc>().currentReciter;
                              final isSelected = currentReciter == reciter;
                              return InkWell(
                                onTap: () {
                                  context.read<AudioBloc>().add(ChangeReciter(reciter));
                                  Navigator.pop(context);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (isSelected)
                                        const Icon(Icons.check, color: AppColors.accentGold, size: 20)
                                      else
                                        const SizedBox(width: 20),
                                      Expanded(
                                        child: Text(
                                          reciter,
                                          style: AppTextStyles.menuItemText.copyWith(
                                            color: isSelected ? AppColors.accentGold : const Color(0xFF2C2520),
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          textAlign: TextAlign.right,
                                          textDirection: TextDirection.rtl,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF2C2520)),
                    onPressed: () {
                      context.read<AudioBloc>().add(const StopAudio());
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.timer_outlined, color: Color(0xFF2C2520)),
                    onPressed: () {
                      // Sleep Timer functionality placeholder
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showReciterSelection(context),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF8C7355).withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF8C7355), size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: BlocBuilder<AudioBloc, AudioState>(
                            builder: (context, state) {
                              final currentReciter = context.read<AudioBloc>().currentReciter;
                              return Text(
                                currentReciter,
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
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF2C2520)),
                onPressed: () {
                  // Settings functionality placeholder
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Playback Speed
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2C2520).withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      '1.0x',
                      style: TextStyle(
                        color: Color(0xFF2C2520),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                  // Repeat/Loop
                  IconButton(
                    icon: const Icon(Icons.repeat_rounded, color: Color(0xFF2C2520)),
                    onPressed: () {
                      // Repeat functionality placeholder
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
