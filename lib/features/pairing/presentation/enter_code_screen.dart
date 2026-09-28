import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../data/pairing_repository.dart';
import '../domain/pair_request.dart';

class EnterCodeScreen extends ConsumerStatefulWidget {
  const EnterCodeScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends ConsumerState<EnterCodeScreen> {
  late final _code = TextEditingController(
    text: widget.initialCode == null
        ? ''
        : PairingRepository.normalizeCode(widget.initialCode!).replaceFirst('VISAL-', ''),
  );
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = 'VISAL-${_code.text}';
    if (!PairingRepository.isValidCode(code)) {
      context.showSnack('Kod VISAL-XXXXX biçiminde olmalı');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(pairingRepositoryProvider).requestPairing(code);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    final code = await context.push<String>(Routes.pairingScan);
    if (code != null && mounted) {
      _code.text = PairingRepository.normalizeCode(code).replaceFirst('VISAL-', '');
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final outgoing = ref.watch(outgoingPairRequestProvider).value;
    final rejected = _sent && outgoing?.status == PairRequestStatus.rejected;

    return Scaffold(
      appBar: AppBar(title: const Text('Partnerimin Kodu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            if (_sent && !rejected) ...[
              const SizedBox(height: 40),
              EmptyState(
                icon: Icons.hourglass_top_rounded,
                emoji: '💌',
                title: 'İsteğin gönderildi',
                message:
                    '${outgoing?.toName ?? 'Partnerin'} onayladığında ikinize ait alan otomatik olarak açılacak.',
              ),
            ] else ...[
              Text(
                'Partnerinin paylaştığı kodu gir.',
                style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
              ),
              if (rejected) ...[
                const SizedBox(height: 16),
                VisalCard(
                  child: Text(
                    'İstek reddedildi. Kodu kontrol edip tekrar deneyebilirsin.',
                    style: context.text.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              TextField(
                controller: _code,
                autofocus: widget.initialCode == null,
                textCapitalization: TextCapitalization.characters,
                maxLength: 5,
                style: context.text.headlineSmall?.copyWith(letterSpacing: 6),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  TextInputFormatter.withFunction(
                    (_, v) => v.copyWith(text: v.text.toUpperCase()),
                  ),
                ],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 4),
                    child: Text(
                      'VISAL-',
                      style: context.text.headlineSmall?.copyWith(
                        color: context.palette.muted,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  hintText: '4X72Q',
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Eşleşme İsteği Gönder', onPressed: _submit, loading: _loading),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('QR Kodu Tara'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
