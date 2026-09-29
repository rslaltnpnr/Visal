import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/visal_logo.dart';

/// Sunucu bağlantı bilgileri olmadan derlenmiş sürümde gösterilir.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VISAL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(
        backgroundColor: AppColors.midnight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const VisalVerticalLogo(markSize: 96),
                const SizedBox(height: 48),
                Text(
                  'Sunucu bağlantısı yapılandırılmamış',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu sürüm Supabase proje adresi ve anahtarı olmadan derlendi. '
                  'SUPABASE_URL ve SUPABASE_ANON_KEY değerleriyle yeniden derleyin.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.lavenderGrey, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
