import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:scenickazatva_app/requests/FirestoreService.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:scenickazatva_app/providers/InfoProvider.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:scenickazatva_app/pages/SettingsPage.dart';
import 'package:scenickazatva_app/pages/TabPage.dart';
import 'package:scenickazatva_app/pages/EventDetailPage.dart';
import 'package:scenickazatva_app/pages/NewsDetailPage.dart';
import 'package:scenickazatva_app/pages/EventEditPage.dart';
import 'package:scenickazatva_app/pages/InfoDetailPage.dart';
import 'package:scenickazatva_app/pages/FavoritesPage.dart';
import 'package:scenickazatva_app/models/ColorScheme.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:scenickazatva_app/requests/NotificationService.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final _router = GoRouter(
    routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => TabPage(initialIndex: 0),
          routes: [
            GoRoute(
                path: 'news',
                builder: (context, state) => TabPage(initialIndex: 2),
                routes: [
                  GoRoute(
                    path: ':newsId',
                    builder: (context, state) =>
                        NewsDetailPage(newsId: state.pathParameters["newsId"]),
                  ),
                ]),
            GoRoute(
                path: 'magazine',
                builder: (context, state) => TabPage(initialIndex: 0),
                routes: [
                  GoRoute(
                    path: ':magazineId',
                    builder: (context, state) => NewsDetailPage(
                        newsId: state.pathParameters["magazineId"]),
                  ),
                ]),
            GoRoute(
                path: 'events',
                builder: (context, state) => TabPage(initialIndex: 1),
                routes: [
                  GoRoute(
                    path: ':eventId',
                    builder: (context, state) => EventDetailPage(
                        eventId: state.pathParameters["eventId"]),
                  ),
                  GoRoute(
                    path: ':eventId/edit',
                    builder: (context, state) =>
                        EventEditPage(eventId: state.pathParameters["eventId"]),
                  ),
                ]),
            GoRoute(
                path: 'info',
                builder: (context, state) => TabPage(initialIndex: 3),
                routes: [
                  GoRoute(
                    path: ':infoId',
                    builder: (context, state) =>
                        InfoDetailPage(infoId: state.pathParameters["infoId"]),
                  )
                ]),
            GoRoute(
              path: 'settings',
              builder: (context, state) => SettingsPage(),
            ),
            GoRoute(
              path: 'favorites',
              builder: (context, state) => FavoritesPage(),
            ),
            GoRoute(
              path: 'user',
              builder: (context, state) => SettingsPage(),
            ),
          ]),
    ],
    onException: (_, state, _router) {
      _router.go('/magazine');
    });

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // print("Notification shown!");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    await NotificationService().init();
  }

  // Initialize Authentication
  FirebaseAuth.instance.idTokenChanges().listen((User? user) async {
    if (user == null) {
      await authService().authFirebase();
    } else {
      print('Auth state changed: ${user.uid}');
    }
  });

  await Hive.initFlutter();
  Hive.registerAdapter(FestivalAdapter());
  Hive.registerAdapter(AppSettingsAdapter());

  FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var userSettings = await authService().getUserData(user);
      userSettings.fcmtoken = fcmToken;
      await authService().saveUserData(userSettings);
    }
  }).onError((err) {
    print("Token refresh error: $err");
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });

  initializeDateFormatting('sk_SK').then((_) => runApp(MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProxyProvider<AppSettingsProvider, FestivalProvider>(
          create: (_) => FestivalProvider(),
          update: (context, settingsProvider, festivalProvider) {
            return festivalProvider!..updateFromSettings(settingsProvider.settings);
          },
        ),
        ChangeNotifierProxyProvider<AppSettingsProvider, EventsProvider>(
          create: (_) => EventsProvider(),
          update: (_, settings, events) => events!..updateFromSettings(settings),
        ),
        ChangeNotifierProxyProvider<FestivalProvider, NewsProvider>(
          create: (_) => NewsProvider(),
          update: (context, festivalProvider, newsProvider) {
            return newsProvider!..updateFromFestival(festivalProvider.festival);
          },
        ),
        ChangeNotifierProxyProvider<FestivalProvider, InfoProvider>(
          create: (_) => InfoProvider(),
          update: (context, festivalProvider, infoProvider) {
            return infoProvider!..updateFromFestival(festivalProvider.festival);
          },
        ),
      ],

      child: MaterialApp.router(
        title: "javisko.sk",
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            fontFamily: 'Space Grotesk',
            appBarTheme: AppBarTheme(
                iconTheme: IconThemeData(color: lightColor),
                backgroundColor: darkColor,
                foregroundColor: lightColor),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: accentColor,
              indicatorColor: accentColorDarker,
              indicatorShape: BeveledRectangleBorder(),
              labelTextStyle:
                  WidgetStateProperty.all(TextStyle(color: darkColor)),
            ),
            listTileTheme: ListTileThemeData(
              textColor: darkColorLighter,
              titleTextStyle: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontVariations: [FontVariation('wght', 700)],
                  color: darkColor,
                  fontSize: 18.0),
            ),
            textTheme: TextTheme(
              displayLarge: TextStyle(
                  fontSize: 24.0,
                  fontVariations: [FontVariation('wght', 700)],
                  color: darkColor),
              displayMedium: TextStyle(
                  fontSize: 18.0,
                  fontStyle: FontStyle.italic,
                  color: darkColor),
              displaySmall: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: darkColor),
              titleLarge: TextStyle(
                  fontSize: 19.0,
                  color: darkColor),
              bodyLarge: TextStyle(fontSize: 14.0, color: darkColor),
              bodyMedium: TextStyle(fontSize: 14.0, color: darkColor),
            )),
        darkTheme: ThemeData(useMaterial3: true, colorScheme: darkColorScheme),
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
      ),
    );
  }
}
