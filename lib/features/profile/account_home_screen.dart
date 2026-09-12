import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/app_providers.dart';
import '../../core/services/session_controller.dart';
import '../../shared/models/account.dart';

/// Account workspace; never reads the local demonstration commerce repository.
class AccountHomeScreen extends ConsumerStatefulWidget {
  const AccountHomeScreen({super.key});
  @override
  ConsumerState<AccountHomeScreen> createState() => _AccountHomeScreenState();
}

class _AccountHomeScreenState extends ConsumerState<AccountHomeScreen> {
  String t(String en, String hi) => context.isHindi ? hi : en;
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final account = session.account;
    if (session.status == SessionStatus.unavailable) {
      return Scaffold(
          body: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48),
                        const SizedBox(height: 24),
                        Text(
                            t('We couldn’t load your account.',
                                'आपका खाता लोड नहीं हुआ।'),
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 16),
                        Text(t('Check your connection and try again.',
                            'कनेक्शन जाँचें और फिर कोशिश करें।')),
                        const SizedBox(height: 24),
                        FilledButton(
                            onPressed: session.resolveIdentity,
                            child: Text(t('Try again', 'फिर कोशिश करें'))),
                        TextButton(
                            onPressed: session.signOut,
                            child: Text(t('Sign out', 'साइन आउट'))),
                      ]))));
    }
    if (account == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final artisan = account.role == AccountRole.artisan;
    return Scaffold(
      appBar: AppBar(title: const Text('Aakar'), actions: [
        IconButton(
            tooltip: t('Go to home', 'होम पर जाएँ'),
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined)),
        IconButton(
            tooltip: t('Choose your language', 'अपनी भाषा चुनें'),
            onPressed: () => context.push('/language'),
            icon: const Icon(Icons.language)),
        IconButton(
            tooltip: t('Sign out', 'साइन आउट'),
            onPressed: session.signOut,
            icon: const Icon(Icons.logout)),
      ]),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    const SizedBox(height: 32),
                    Text(t('Welcome,', 'स्वागत है,'),
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        artisan
                            ? account.name ?? ''
                            : account.businessName ?? account.name ?? '',
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text(artisan
                        ? t('A space for your craft to grow.',
                            'आपकी कला को आगे बढ़ाने की जगह।')
                        : t('Good business begins with trusted connections.',
                            'अच्छा व्यवसाय भरोसेमंद संबंधों से शुरू होता है।')),
                    const SizedBox(height: 30),
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                      account.isVerified
                                          ? Icons.verified_outlined
                                          : Icons.shield_outlined,
                                      size: 36,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(height: 18),
                                  Text(
                                      account.isVerified
                                          ? t('Account verified',
                                              'खाता सत्यापित')
                                          : t('Build trust with verification',
                                              'सत्यापन से भरोसा बढ़ाएँ'),
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 12),
                                  Text(t(
                                      'Manage your documents and check your review status.',
                                      'अपने दस्तावेज़ और समीक्षा की स्थिति देखें।')),
                                  const SizedBox(height: 18),
                                  FilledButton(
                                      onPressed: () =>
                                          context.push('/verification'),
                                      child: Text(t('View verification',
                                          'सत्यापन देखें'))),
                                ]))),
                    const SizedBox(height: 18),
                    Card(
                        child: Column(children: [
                      ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(t('Your profile', 'आपकी प्रोफ़ाइल')),
                          subtitle: Text(
                              '${account.name ?? ''}\n${account.phone ?? ''}'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/profile/edit')),
                      ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text([
                            account.profile['district'],
                            account.state
                          ]
                              .whereType<String>()
                              .where((v) => v.isNotEmpty)
                              .join(', '))),
                    ])),
                  ])))),
    );
  }
}
