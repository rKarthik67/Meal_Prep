import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/emoji_art.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _busy = false;
  bool _otpSent = false;
  String? _verificationId; // mobile
  fb.ConfirmationResult? _webConfirmation; // web

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');
  String get _e164 => _digits.length == 10 ? '+91$_digits' : '+$_digits';

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    if (_digits.length < 10) {
      showError(context, 'Enter a valid 10-digit mobile number');
      return;
    }
    final session = context.read<Session>();
    if (!useFirebase) return _run(() => session.devLogin(_e164));
    return _run(_sendOtp);
  }

  Future<void> _sendOtp() async {
    final auth = fb.FirebaseAuth.instance;
    if (kIsWeb) {
      _webConfirmation = await auth.signInWithPhoneNumber(_e164);
      setState(() => _otpSent = true);
      return;
    }
    await auth.verifyPhoneNumber(
      phoneNumber: _e164,
      verificationCompleted: (cred) async {
        await auth.signInWithCredential(cred); // Android SMS auto-read
        if (mounted) await context.read<Session>().firebaseSignedIn();
      },
      verificationFailed: (e) {
        if (mounted) showError(context, e.message ?? e.code);
      },
      codeSent: (id, _) => setState(() {
        _verificationId = id;
        _otpSent = true;
      }),
      codeAutoRetrievalTimeout: (id) => _verificationId = id,
    );
  }

  Future<void> _verifyOtp() => _run(() async {
        final session = context.read<Session>();
        if (kIsWeb) {
          await _webConfirmation!.confirm(_otp.text.trim());
        } else {
          final cred = fb.PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: _otp.text.trim());
          await fb.FirebaseAuth.instance.signInWithCredential(cred);
        }
        await session.firebaseSignedIn();
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(children: [
              // ---------- hero
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 28, 24, 36),
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(
                        height: 170,
                        child: Stack(children: [
                          Positioned(right: 0, top: 0, child: EmojiArt('🍛', size: 150)),
                          Positioned(left: 0, bottom: 0, child: EmojiArt('🧑‍🍳', size: 110)),
                          Positioned(left: 110, top: 10, child: EmojiArt('🫓', size: 64)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      Text('Ghar ka khana,\nwithout the cooking.',
                          style: t.headlineMedium?.copyWith(color: Colors.white, height: 1.2)),
                      const SizedBox(height: 8),
                      Text('Book a verified home cook in minutes.',
                          style: t.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                    ]),
                  ),
                ),
              ),
              // ---------- form
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(_otpSent ? 'Enter the OTP' : 'Log in or sign up', style: t.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        _otpSent ? 'We sent a 6-digit code to $_e164' : 'We\'ll verify your number with a one-time code.',
                        style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _phone,
                        enabled: !_otpSent,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        style: t.titleMedium?.copyWith(letterSpacing: 1.2),
                        decoration: const InputDecoration(
                          hintText: '98765 43210',
                          prefixIcon: Padding(
                            padding: EdgeInsets.fromLTRB(16, 14, 8, 14),
                            child: Text('🇮🇳  +91', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: _otp,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                          style: t.headlineSmall?.copyWith(letterSpacing: 12),
                          decoration: const InputDecoration(hintText: '••••••'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      GradientButton(
                        label: _otpSent ? 'Verify & continue' : (useFirebase ? 'Send OTP' : 'Continue'),
                        icon: Icons.arrow_forward_rounded,
                        busy: _busy,
                        onPressed: _otpSent ? _verifyOtp : _continue,
                      ),
                      if (_otpSent)
                        TextButton(
                          onPressed: _busy ? null : () => setState(() => _otpSent = false),
                          child: const Text('Change number'),
                        ),
                      if (!useFirebase) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.aiViolet.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(children: [
                            const Icon(Icons.developer_mode_rounded, color: AppColors.aiViolet),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Dev mode: no OTP needed. Demo cooks: 9000000001 – 9000000003.',
                                style: t.bodySmall,
                              ),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'By continuing you agree to our Terms & Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}
