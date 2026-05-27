import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  //final bool _running = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  Future<Map<Object, Object>> getPushSettings() async {
    DatabaseReference festivalsdb =
        FirebaseDatabase.instance.ref("appsettings/festivals");
    final festivals = await festivalsdb.get();
    if (festivals.exists) {
      final _uid = FirebaseAuth.instance.currentUser?.uid;
      DatabaseReference usersdb =
          FirebaseDatabase.instance.ref("users/$_uid/notifications");

      final userSettings = await usersdb.get();

      final _festivals = festivals.value as Map;
      final _user = userSettings.value as Map;
      Map<String, bool> _data = {};

      _festivals.forEach((key, value) {
        if (key != null) {
          _data[key] = _user[key] != null ? _user[key] : true;
        }
      });
      return _data;
    } else {
      print('No data in AppSettings');
      return {};
    }
  }
/*
  Stream<Map<Object, Object>> _pushStream() async* {
    while (_running) {
      Map<Object, Object> _data = await getPushSettings();
      yield _data;
    }
  }*/

  Widget buildForm(BuildContext context, user){
    String roleValue = "user";
    return Container(
        padding: EdgeInsets.all(45),
        child: Form(
            key: _formKey,
            child: Column(children: <Widget>[
                TextFormField(
                  initialValue: user.displayName,
                  decoration: const InputDecoration(
                    icon: Icon(Icons.person),
                    hintText: 'Ako ťa volajú?',
                    labelText: 'Meno',
                  ),
                ),
               DropdownButtonFormField(
                  initialValue: roleValue,
                  items: <String>["admin", "editor", "user"]
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(fontSize: 20),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) => setState(() {
                      roleValue = newValue!;
                    }),
                ),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final providers = [EmailAuthProvider()];
    final festivalProvider = Provider.of<FestivalProvider>(context);
    final festival = festivalProvider.festival;
    final settingsProvider = Provider.of<AppSettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
            ),
            onPressed: () {
              context.go("/");
            }),
        title: const Text(
          "Nastavenia",
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Veľkosť písma", style: Theme.of(context).textTheme.displaySmall),
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
                    if (kIsWeb) ...[
                      Text("Konto", style: Theme.of(context).textTheme.displaySmall),
                      SizedBox(
                        height: 400, // Fixed height for profile section to coexist with other settings
                        child: StreamBuilder(
                          stream: FirebaseAuth.instance.authStateChanges(),
                          initialData: FirebaseAuth.instance.currentUser,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final user = snapshot.data;
                              if (FirebaseAuth.instance.currentUser!.isAnonymous) {
                                return SignInScreen(
                                  providers: providers,
                                  actions: [
                                    AuthStateChangeAction<SignedIn>((context, state) {
                                      Navigator.pushReplacementNamed(context, '/profile');
                                    }),
                                  ],
                                );
                              } else {
                                return ProfileScreen(
                                  providers: providers,
                                  actions: [
                                    SignedOutAction((context) {
                                      Navigator.pushReplacementNamed(context, '/sign-in');
                                    }),
                                  ],
                                  children: [buildForm(context, user)],
                                );
                              }
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      const Divider(),
                    ],
                    Text("Push notifikácie", style: Theme.of(context).textTheme.displaySmall),
                    SwitchListTile(
                      title: const Text("Povoliť push notifikácie"),
                      subtitle: const Text(
                          'Krátke správy o tom, že sa blíži predstavenie, ktoré sa zobrazujú medzi upozorneniami.'),
                      value: settingsProvider.settings.notificationsEnabled,
                      onChanged: (bool value) {
                        settingsProvider.updateNotificationsEnabled(value);
                      },
                    ),
                    const Divider(),
                    Text("Pripomienky", style: Theme.of(context).textTheme.displaySmall),
                    SwitchListTile(
                      title: const Text("Pripomienky pre obľúbené"),
                      subtitle: const Text(
                          'Dostávať lokálne upozornenia na podujatia, ktoré máte označené ako obľúbené.'),
                      value: settingsProvider.settings.remindersEnabled,
                      onChanged: (bool value) {
                        settingsProvider.updateRemindersEnabled(value);
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

  void changeSubscription(topic, value) async {
    final _uid = FirebaseAuth.instance.currentUser?.uid;
    if (value == true) {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    }

    DatabaseReference users = FirebaseDatabase.instance.ref("users/$_uid");
    users.update({
      "notifications/$topic": value,
    }).then((_) {});
  }
/*
  Widget _buildLoadingScreen() {
    return Center(
      child: Container(
        width: 50,
        height: 50,
        child: CircularProgressIndicator(),
      ),
    );
  }
 */
}
