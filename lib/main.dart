import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import 'package:scenickazatva_app/pages/LocationDetailPage.dart';
import 'package:scenickazatva_app/pages/LocationEditPage.dart';
import 'package:scenickazatva_app/pages/FavoritesPage.dart';
import 'package:scenickazatva_app/pages/ReadLaterPage.dart';

import 'package:scenickazatva_app/pages/GamesListPage.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/models/Ad.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:scenickazatva_app/providers/GameProvider.dart';
import 'package:scenickazatva_app/providers/QuizDraftProvider.dart';
import 'package:scenickazatva_app/pages/GamePage.dart';
import 'package:scenickazatva_app/pages/GameQuestionPage.dart';
import 'package:scenickazatva_app/pages/GameResultsPage.dart';
import 'package:scenickazatva_app/pages/GameEditPage.dart';
import 'package:scenickazatva_app/pages/GameQuestionEditPage.dart';
import 'package:scenickazatva_app/pages/LiveGameControlPage.dart';
import 'package:scenickazatva_app/requests/NotificationService.dart';
import 'package:scenickazatva_app/requests/ConnectivityService.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/requests/AnalyticsEvents.dart';
import 'package:scenickazatva_app/utils/ThemeFactory.dart';
import 'package:scenickazatva_app/utils/AppLog.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:app_links/app_links.dart';
import 'package:scenickazatva_app/utils/DeepLinks.dart';

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
                path: 'locations',
                builder: (context, state) => TabPage(initialIndex: 1),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const LocationEditPage(),
                  ),
                  GoRoute(
                    path: ':locationId',
                    builder: (context, state) =>
                        LocationDetailPage(locationId: state.pathParameters["locationId"] ?? ""),
                  ),
                  GoRoute(
                    path: ':locationId/edit',
                    builder: (context, state) =>
                        LocationEditPage(locationId: state.pathParameters["locationId"] ?? ""),
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
              path: 'read-later',
              builder: (context, state) => const ReadLaterPage(),
            ),
            GoRoute(
              path: 'games',
              builder: (context, state) => const GamesListPage(),
            ),
            GoRoute(
              path: 'game',
              redirect: (context, state) => '/games',
            ),
            GoRoute(
              path: 'game/:gameId',
              builder: (context, state) => GamePage(
                gameId: state.pathParameters['gameId'] ?? '',
              ),
              routes: [
                GoRoute(
                  path: 'results',
                  builder: (context, state) => GameResultsPage(
                    gameId: state.pathParameters['gameId'] ?? '',
                  ),
                ),
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => GameEditPage(
                    gameId: state.pathParameters['gameId'] ?? '',
                  ),
                  routes: [
                    GoRoute(
                      path: ':questionId',
                      builder: (context, state) => GameQuestionEditPage(
                        gameId: state.pathParameters['gameId'] ?? '',
                        questionId: state.pathParameters['questionId'] ?? "new",
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'live',
                  builder: (context, state) => LiveGameControlPage(
                    gameId: state.pathParameters['gameId'] ?? '',
                  ),
                ),
                GoRoute(
                  path: ':questionId',
                  builder: (context, state) => GameQuestionPage(
                    gameId: state.pathParameters['gameId'] ?? '',
                    questionId: state.pathParameters['questionId'] ?? "",
                  ),
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

  const appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

  // Parallelize independent initializations
  await Future.wait([
    FirebaseAppCheck.instance.activate(
      providerAndroid: appCheckDebugToken.isNotEmpty
          ? AndroidDebugProvider(debugToken: appCheckDebugToken)
          : AndroidDebugProvider(),
      providerApple: appCheckDebugToken.isNotEmpty
          ? AppleDebugProvider(debugToken: appCheckDebugToken)
          : AppleDebugProvider(),
      providerWeb: ReCaptchaV3Provider('6Lcj-R8qAAAAABpZ_O_U_9_Z_Z_Z_Z_Z_Z_Z_Z'),
    ),
    ConnectivityService.instance.init(),
    Hive.initFlutter().then((_) {
      Hive.registerAdapter(FestivalAdapter());
      Hive.registerAdapter(AppSettingsAdapter());
      Hive.registerAdapter(AdAdapter());
    }),
  ]);

  if (!kIsWeb) {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    
    // Handle local notification taps
    NotificationService().onNotificationTap = (String payload) {
      Analytics().logEvent(AnalyticsEvents.notificationTapped, parameters: {
        AnalyticsEvents.paramPayload: payload,
      });
      _router.push(payload);
    };

    // Defer non-critical init to after first frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      NotificationService().init();
      FirebaseMessaging.instance.subscribeToTopic('magazine_updates');
      FirebaseMessaging.instance.subscribeToTopic('news_updates');
    });
  }

  // Initialize Authentication
  fauth.FirebaseAuth.instance.idTokenChanges().listen((fauth.User? user) async {
    if (user == null) {
      await authService().authFirebase();
    } else {
      AppLog.info('Auth state changed: ${user.uid}');
    }
  });

  // Retry auth when connectivity is restored (e.g. first run offline).
  ConnectivityService.instance.addListener(() {
    if (ConnectivityService.instance.isOnline &&
        fauth.FirebaseAuth.instance.currentUser == null) {
      AppLog.info('Connectivity restored, retrying anonymous auth');
      authService().authFirebase();
    }
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
    final user = fauth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      var userSettings = await authService().getUserData(user);
      userSettings.fcmtoken = fcmToken;
      await authService().saveUserData(userSettings);
    }
  }).onError((err) {
    AppLog.error("Token refresh error", error: err);
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    AppLog.info('Got a message whilst in the foreground!');
    if (message.notification != null) {
      AppLog.info('Message also contained a notification: ${message.notification}');
    }
  });

  if (!kIsWeb) _initDeepLinks();

  initializeDateFormatting('sk_SK').then((_) => runApp(MyApp()));
}

/// Cold-start and warm-start deep-link routing. Web is skipped because
/// go_router owns the browser URL there.
Future<void> _initDeepLinks() async {
  final appLinks = AppLinks();
  try {
    final initial = await appLinks.getInitialLink();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final path = DeepLinks.normalizeDeepLink(initial.toString());
        if (path != null) _router.push(path);
      });
    }
    appLinks.uriLinkStream.listen((uri) {
      final path = DeepLinks.normalizeDeepLink(uri.toString());
      if (path != null) _router.push(path);
    });
  } catch (e) {
    AppLog.error('Deep links init failed', error: e);
  }
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
        ChangeNotifierProvider(create: (_) => QuizDraftProvider()),
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
                builder: (context, child) => child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
