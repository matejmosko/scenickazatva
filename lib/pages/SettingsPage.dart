import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  @override
  void initState() {
    super.initState();
  }

  Widget _buildUserInfo(BuildContext context, User? user) {
    if (user == null) return const SizedBox();
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Prihlásený ako:", style: Theme.of(context).textTheme.bodySmall),
            Text(user.email ?? user.displayName ?? "Anonymný užívateľ", 
                 style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text("UID: ${user.uid}", style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text("Rola: ${userProvider.userData.userRole.isNotEmpty ? userProvider.userData.userRole : 'user'}",
                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                   fontStyle: FontStyle.italic,
                   color: Theme.of(context).colorScheme.primary,
                   fontWeight: FontWeight.bold,
                 )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<AppSettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.go("/")),
        title: const Text("Nastavenia"),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              Analytics().logEvent(AnalyticsEvents.menuSettings);
              context.go('/settings');
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Vzhľad a písmo", style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 16),
                    Text("Veľkosť písma", style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      children: [
                        const Icon(Icons.text_fields, size: 16),
                        Expanded(
                          child: Slider(
                            value: settingsProvider.settings.fontSizeFactor,
                            min: 0.8,
                            max: 1.6,
                            divisions: 8,
                            label: "${(settingsProvider.settings.fontSizeFactor * 100).toInt()}%",
                            onChanged: (double value) {
                              settingsProvider.updateFontSizeFactor(value);
                            },
                          ),
                        ),
                        const Icon(Icons.text_fields, size: 28),
                      ],
                    ),
                    const Divider(),
                    Text("Notifikácie", style: Theme.of(context).textTheme.displaySmall),
                    SwitchListTile(
                      title: const Text("Povoliť push notifikácie"),
                      subtitle: const Text(
                          'Krátke správy o tom, že sa blíži predstavenie, ktoré sa zobrazujú medzi upozorneniami.'),
                      value: settingsProvider.settings.notificationsEnabled,
                      onChanged: (bool value) {
                        settingsProvider.updateNotificationsEnabled(value);
                      },
                    ),
                    SwitchListTile(
                      title: const Text("Pripomienky pre obľúbené"),
                      subtitle: const Text(
                          'Dostávať lokálne upozornenia na podujatia, ktoré máte označené ako obľúbené.'),
                      value: settingsProvider.settings.remindersEnabled,
                      onChanged: (bool value) {
                        settingsProvider.updateRemindersEnabled(value);
                      },
                    ),
                    const Divider(),
                    Text("Pokročilé", style: Theme.of(context).textTheme.displaySmall),
                    SwitchListTile(
                      title: const Text("Otvárať linky z javisko.sk v apke."),
                      subtitle: const Text(
                          'Ak je zapnuté, odkazy na javisko.sk sa budú otvárať priamo v aplikácii.'),
                      value: settingsProvider.settings.interceptLinks,
                      onChanged: (bool value) {
                        settingsProvider.updateInterceptLinks(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Login Section - Visually different
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.blueGrey.withValues(alpha: 0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              ),
              padding: const EdgeInsets.all(24),
              child: Theme(
                // Fix white on white buttons
                data: Theme.of(context).copyWith(
                  elevatedButtonTheme: ElevatedButtonThemeData(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary == Colors.white 
                          ? const Color(0xffCCA965) 
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xffCCA965),
                      side: BorderSide(color: isDark ? Colors.white24 : const Color(0xffCCA965)),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_person, color: isDark ? Colors.white70 : Colors.grey),
                        const SizedBox(width: 8),
                        Text("Správa konta", style: Theme.of(context).textTheme.displaySmall),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder(
                      stream: FirebaseAuth.instance.authStateChanges(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && !snapshot.data!.isAnonymous) {
                          final user = snapshot.data;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildUserInfo(context, user),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.person),
                                label: const Text("Spravovať profil"),
                                onPressed: () => context.push('/profile'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.logout),
                                label: const Text("Odhlásiť sa"),
                                onPressed: () async {
                                  await FirebaseAuth.instance.signOut();
                                  // authFirebase will automatically sign in anonymously
                                },
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "Na používanie aplikácie sa nepotrebujete prihlasovať. Po prihlásení sa vám uloží zoznam obľúbených položiek a budete si ho môcť zobraziť na každom zariadení, kde budete prihlásení.",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.login),
                                label: const Text("Prihlásiť sa"),
                                onPressed: () => context.push('/login'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
