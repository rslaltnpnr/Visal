import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../data/pairing_repository.dart';
import '../domain/pair_request.dart';
import 'pairing_screen.dart';

/// QR içeriği; tarayıcı bu önekle doğrular.
String pairingQrData(String code) => 'visal://pair?code=$code';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> with IncomingRequestListener {
  Invite? _invite;
  Object? _error;
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _create();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite = await ref.read(pairingRepositoryProvider).createInvite();
      if (mounted) setState(() => _invite = invite);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _share() {
    final code = _invite!.code;
    final name = ref.read(currentUserProvider).value?.firstName ?? '';
    SharePlus.instance.share(ShareParams(
      subject: 'VISAL davet kodu',
      text: '$name seni VISAL\'a davet ediyor. İkinize ait bir dünya için '
          'uygulamada "Partnerimin Kodunu Gir" bölümüne bu kodu yaz: $code',
    ));
  }

  @override
  Widget build(BuildContext context) {
    listenIncoming();
    final invite = _invite;
    final remaining = invite?.expiresAt.difference(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Davet Kodu')),
      body: SafeArea(
        child: _loading
            ? const LoadingView()
            : _error != null
                ? ErrorView(error: _error!, onRetry: _create)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      Text(
                        'Bu kodu partnerinle paylaş. Kodunu girdiğinde onayına bir istek gelecek.',
                        style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
                      ),
                      const SizedBox(height: 28),
                      VisalCard(
                        radius: AppRadii.cardLarge,
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: QrImageView(
                                data: pairingQrData(invite!.code),
                                size: 200,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.circle,
                                  color: AppColors.midnight,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.circle,
                                  color: AppColors.plum,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SelectableText(
                              invite.code,
                              style: context.text.headlineMedium?.copyWith(letterSpacing: 3),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              remaining == null || remaining.isNegative
                                  ? 'Kodun süresi doldu'
                                  : '${remaining.inHours} sa ${remaining.inMinutes.remainder(60)} dk geçerli',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: invite.code));
                                context.showSnack('Kod kopyalandı');
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('Kopyala'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Paylaş',
                              icon: Icons.ios_share_rounded,
                              onPressed: _share,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _create,
                        child: const Text('Yeni kod oluştur'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
