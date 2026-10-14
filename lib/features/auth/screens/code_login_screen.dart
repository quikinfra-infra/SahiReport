// lib/features/auth/screens/code_login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class CodeLoginScreen extends ConsumerStatefulWidget {
  const CodeLoginScreen({super.key});

  @override
  ConsumerState<CodeLoginScreen> createState() => _CodeLoginScreenState();
}

class _CodeLoginScreenState extends ConsumerState<CodeLoginScreen> {
  // 4 controllers — one per code segment (XXXX-XXXX = 2 segments of 4)
  final _part1 = TextEditingController();
  final _part2 = TextEditingController();
  final _focus1 = FocusNode();
  final _focus2 = FocusNode();

  @override
  void dispose() {
    _part1.dispose();
    _part2.dispose();
    _focus1.dispose();
    _focus2.dispose();
    super.dispose();
  }

  String get _fullCode => '${_part1.text}-${_part2.text}';

  bool get _isComplete => _part1.text.length == 4 && _part2.text.length == 4;

  Future<void> _submit() async {
    if (!_isComplete) return;
    await ref.read(authProvider.notifier).loginWithCode(_fullCode);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.error,
          ),
        );
        ref.read(authProvider.notifier).clearError();
        // Clear code on error
        _part1.clear();
        _part2.clear();
        _focus1.requestFocus();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ─────────────────────────────────────
                      const Text(
                        'Enter Access Code',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the code provided by your project owner\nto access your assigned project.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7A90B8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ── Code input ─────────────────────────────────
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CodeSegment(
                              controller: _part1,
                              focusNode: _focus1,
                              autofocus: true,
                              onComplete: () => _focus2.requestFocus(),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '—',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Color(0xFF4A5A7A),
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                            _CodeSegment(
                              controller: _part2,
                              focusNode: _focus2,
                              onComplete: _submit,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Format: XXXX—XXXX',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // ── Submit button ──────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                          (!_isComplete || authState.isLoading) ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isComplete
                                ? AppTheme.navyMid
                                : const Color(0xFF1E3A6E),
                            disabledBackgroundColor: const Color(0xFF1E3A6E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                            'Access Project',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const Expanded(child: SizedBox.shrink()),

                      // ── Help text ──────────────────────────────────
                      Center(
                        child: Text(
                          'Contact your project owner if you don\'t have a code.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Individual 4-char code segment input ──────────────────────
class _CodeSegment extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback? onComplete;

  const _CodeSegment({
    required this.controller,
    required this.focusNode,
    this.autofocus = false,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        maxLength: 4,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 6,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFF1E3A6E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppTheme.navyAccent,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 12,
          ),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          UpperCaseTextFormatter(),
        ],
        onChanged: (v) {
          if (v.length == 4) onComplete?.call();
        },
      ),
    );
  }
}

// Auto-uppercase formatter
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}