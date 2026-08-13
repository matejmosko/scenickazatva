import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart' as fauth;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
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
import 'package:scenickazatva_app/pages/InfoEditPage.dart';
import 'package:scenickazatva_app/pages/InfoDetailPage.dart';
import 'package:scenickazatva_app/pages/FavoritesPage.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/Ad.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/pages/GamePage.dart';
import 'package:scenickazatva_app/pages/GameQuestionPage.dart';
import 'package:scenickazatva_app/pages/GameResultsPage.dart';
import 'package:scenickazatva_app/pages/GameEditPage.dart';
import 'package:scenickazatva_app/pages/GameQuestionEditPage.dart';
import 'package:scenickazatva_app/requests/NotificationService.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/utils/ThemeFactory.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;

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
                        eventId: state.pathParameters["eventId"] ?? ""),
                  ),
                  GoRoute(
                    path: ':eventId/edit',
                    builder: (context, state) =>
                        EventEditPage(eventId: state.pathParameters["eventId"] ?? ""),
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
                  ),
                  GoRoute(
                    path: ':infoId/edit',
                    builder: (context, state) =>
                        InfoEditPage(infoId: state.pathParameters["infoId"] ?? ""),
                  )
                ]),
            GoRoute(
              path: 'settings',
              builder: (context, state) => SettingsPage(),
            ),
            GoRoute(
              path: 'login',
              builder: (context, state) => Scaffold(
                appBar: AppBar(
                  title: const Text("Prihlásenie"),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/settings');
                      }
                    },
                  ),
                ),
                body: SignInScreen(
                  providers: [EmailAuthProvider()],
                  actions: [
                    AuthStateChangeAction<SignedIn>((context, state) {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/settings');
                      }
                    }),
                    AuthStateChangeAction<UserCreated>((context, state) {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/settings');
                      }
                    }),
                  ],
                ),
              ),
            ),
            GoRoute(
              path: 'profile',
              builder: (context, state) => Scaffold(
                appBar: AppBar(
                  title: const Text("Môj profil"),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/settings');
                      }
                    },
                  ),
                ),
                body: ProfileScreen(
                  providers: [EmailAuthProvider()],
                  actions: [
                    SignedOutAction((context) {
                      context.go('/settings');
                    }),
                  ],
                ),
              ),
            ),
            GoRoute(
              path: 'favorites',
              builder: (context, state) => FavoritesPage(),
            ),
            GoRoute(
              path: 'game',
              builder: (context, state) => const GamePage(),
              routes: [
                GoRoute(
                  path: 'results',
                  builder: (context, state) => const GameResultsPage(),
                ),
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const GameEditPage(),
                  routes: [
                    GoRoute(
                      path: ':questionId',
                      builder: (context, state) => GameQuestionEditPage(
                          questionId: state.pathParameters["questionId"] ?? "new"),
                    ),
                  ],
                ),
                GoRoute(
                  path: ':questionId',
                  builder: (context, state) => GameQuestionPage(
                      questionId: state.pathParameters["questionId"] ?? ""),
                ),
              ],
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
  // debugPrint("Notification shown!");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize App Check to silence "No AppCheckProvider installed" warnings
  // We use debug provider for development/emulator environments
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
    webProvider: ReCaptchaV3Provider('6Lcj-R8qAAAAABpZ_O_U_9_Z_Z_Z_Z_Z_Z_Z_Z'),
  );

  if (!kIsWeb) {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    
    // Handle local notification taps
    NotificationService().onNotificationTap = (String payload) {
      Analytics().logEvent(AnalyticsEvents.notificationTapped, parameters: {
        AnalyticsEvents.paramPayload: payload,
      });
      _router.push(payload);
    };

    await NotificationService().init();
    
    // Subscribe to global topics for new articles
    FirebaseMessaging.instance.subscribeToTopic('magazine_updates');
    FirebaseMessaging.instance.subscribeToTopic('news_updates');
  }

  // Initialize Authentication
  fauth.FirebaseAuth.instance.idTokenChanges().listen((fauth.User? user) async {
    if (user == null) {
      await authService().authFirebase();
    } else {
      debugPrint('Auth state changed: ${user.uid}');
    }
  });

  await Hive.initFlutter();
  Hive.registerAdapter(FestivalAdapter());
  Hive.registerAdapter(AppSettingsAdapter());
  Hive.registerAdapter(AdAdapter());

  FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
    final user = fauth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      var userSettings = await authService().getUserData(user);
      userSettings.fcmtoken = fcmToken;
      await authService().saveUserData(userSettings);
    }
  }).onError((err) {
    debugPrint("Token refresh error: $err");
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    if (message.notification != null) {
      debugPrint('Message also contained a notification: ${message.notification}');
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
        ChangeNotifierProxyProvider2<AppSettingsProvider, UserProvider, EventsProvider>(
          create: (_) => EventsProvider(),
          update: (_, settings, user, events) {
            events!.updateFromUser(user.canEdit);
            return events..updateFromSettings(settings);
          },
        ),
        ChangeNotifierProxyProvider2<FestivalProvider, AppSettingsProvider, NewsProvider>(
          create: (_) => NewsProvider(),
          update: (context, festivalProvider, settingsProvider, newsProvider) {
            newsProvider!.updateFromSettings(settingsProvider.settings);
            return newsProvider..updateFromFestival(festivalProvider.festival);
          },
        ),
        ChangeNotifierProxyProvider2<FestivalProvider, UserProvider, InfoProvider>(
          create: (_) => InfoProvider(),
          update: (context, festivalProvider, user, infoProvider) {
            infoProvider!.updateFromUser(user.canEdit);
            return infoProvider..updateFromFestival(festivalProvider.festival);
          },
        ),
        ChangeNotifierProxyProvider2<FestivalProvider, UserProvider, GameProvider>(
          create: (_) => GameProvider(),
          update: (context, festivalProvider, user, gameProvider) {
            gameProvider!.updateFromUser(user.userData);
            return gameProvider..updateFromFestival(festivalProvider.festival);
          },
        ),
      ],

      child: Consumer<AppSettingsProvider>(
        builder: (context, settingsProvider, child) {
          final fontSizeFactor = settingsProvider.settings.fontSizeFactor;
          return Consumer<FestivalProvider>(
            builder: (context, festivalProvider, child) {
              final festival = festivalProvider.festival;
              Analytics().syncFestival(festival.id);
              return MaterialApp.router(
                title: "javisko.sk",
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  FlutterQuillLocalizations.delegate,
                ],
                theme: buildFestivalTheme(
                    brightness: Brightness.light,
                    fontSizeFactor: fontSizeFactor,
                    festival: festival),
                darkTheme: buildFestivalTheme(
                    brightness: Brightness.dark,
                    fontSizeFactor: fontSizeFactor,
                    festival: festival),
                debugShowCheckedModeBanner: false,
                routerConfig: _router,
              );
            },
          );
        },
      ),
    );
  }
}
