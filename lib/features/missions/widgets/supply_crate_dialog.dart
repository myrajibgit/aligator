import 'package:flutter/material.dart';
import 'package:studycompete/shared/theme/app_theme.dart';
import 'package:studycompete/shared/utils/haptic_feedback_utils.dart';

class SupplyCrateDialog extends StatefulWidget {
  final int xpAwarded;
  final int fatiguePurged;
  final double multiplier;
  final String systemQuote;

  const SupplyCrateDialog({
    super.key,
    required this.xpAwarded,
    required this.fatiguePurged,
    required this.multiplier,
    required this.systemQuote,
  });

  static Future<void> show(
    BuildContext context, {
    required int xpAwarded,
    required int fatiguePurged,
    required double multiplier,
    required String systemQuote,
  }) {
    HapticFeedbackUtils.levelUp();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SupplyCrateDialog(
        xpAwarded: xpAwarded,
        fatiguePurged: fatiguePurged,
        multiplier: multiplier,
        systemQuote: systemQuote,
      ),
    );
  }

  @override
  State<SupplyCrateDialog> createState() => _SupplyCrateDialogState();
}

class _SupplyCrateDialogState extends State<SupplyCrateDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.elasticOut,
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFA855F7),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA855F7).withOpacity(0.4),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFA855F7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📦', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'DAILY GUILD SUPPLY CRATE',
                      style: TextStyle(
                        color: Color(0xFFD8B4FE),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Glowing Icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFFA855F7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🎁', style: TextStyle(fontSize: 44)),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              const Text(
                'SUPPLY DROP UNLOCKED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Daily Hunter rations disbursed by the Guild',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),

              // Reward Cards
              Row(
                children: [
                  // XP Reward
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Column(
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(
                            '+${widget.xpAwarded} XP',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${widget.multiplier.toStringAsFixed(2)}x Streak Multiplier',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Fatigue Purge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                      ),
                      child: Column(
                        children: [
                          const Text('💧', style: TextStyle(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(
                            '-${widget.fatiguePurged}%',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Fatigue Suppressed',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // System quote banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.systemQuote,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Claim button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedbackUtils.selection();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA855F7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                  ),
                  child: const Text(
                    'EQUIP & CONTINUE',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
