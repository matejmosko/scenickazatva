import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:scenickazatva_app/requests/AppSettingsRequest.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:scenickazatva_app/requests/authFirestore.dart';
import 'package:scenickazatva_app/providers/ArrangementProvider.dart';
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
import 'package:scenickazatva_app/models/ColorScheme.dart';
import 'package:scenickazatva_app/models/AppSettings.dart';
import 'package:scenickazatva_app/models/Festival.dart';
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
                builder: (context, state) => TabPage(initialIndex: 0),
                routes: [
                  GoRoute(
                    path: ':newsId',
                    builder: (context, state) =>
                        NewsDetailPage(newsId: state.pathParameters["newsId"]),
                  ),
                ]),
            GoRoute(
                path: 'magazine',
                builder: (context, state) => TabPage(initialIndex: 2),
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
              path: 'user',
              builder: (context, state) => SettingsPage(),
            ),
          ]),
    ],
    onException: (_, state, router) {
      router.go('/news');
    });

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // print("Notification shown!");
}

void main() async {
  //if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await authService().authFirebase();

  FirebaseAuth.instance.idTokenChanges().listen((User? user) async {
    if (user == null) {
      print('User is currently signed out! We cannot get data');
    } else {
      print('User is signed in with UID: ' + user.uid);
      var fcmToken = "";
      if (!kIsWeb) {
        FirebaseDatabase.instance.setPersistenceEnabled(true);
        fcmToken = await authService().getFCMtoken();
      }

      /*final Map<String, Object> initialSettings = {
        "timestamp": DateTime.now().toString(),
        "fcmtoken": fcmToken != null ? fcmToken : "",
        "id": user.uid,
      };*/

      var userSettings = await authService().getUserData(user);

      userSettings.timestamp = DateTime.now().toString();
      userSettings.fcmtoken = fcmToken;
      userSettings.id = user.uid;
/*
      DatabaseReference festivals =
          await FirebaseDatabase.instance.ref("appsettings/festivals");
      var _uid = user.uid;

      festivals.onValue.listen((DatabaseEvent event) async {
        DatabaseReference _usersdb =
            FirebaseDatabase.instance.ref("users/$_uid/notifications");
        final _users = await _usersdb.get();
        print(_users.value);
        final _currentUser = (_users.value as Map);

        final data = (event.snapshot.value as Map);
        final _notifications = {};

        data.forEach((key, value) {
          _notifications[key] = _currentUser != null ? _currentUser[key] : true;

        });

        userSettings.notifications = _notifications;

        FirebaseDatabase.instance
            .ref("users/" + user.uid)
            .update(userSettings.toJson())
            .then((_) {
          //   print("Firebase save success");
        }).catchError((error) {
          print(error);
        });
      });*/
    }
  });

  await Hive.initFlutter();
  Hive.registerAdapter(FestivalAdapter());
  Hive.registerAdapter(AppSettingsAdapter());

  FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) {
    // Note: This callback is fired at each app startup and whenever a new
    // token is generated.
    print("Token changed: $fcmToken");
  }).onError((err) {
    // Error getting token.
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });
  /*} else {
    // Some web specific code there
    // https://stackoverflow.com/questions/58459483/unsupported-operation-platform-operatingsystem
  }*/

  AppSettingsRequest appSettingsRequest = AppSettingsRequest();
  appSettingsRequest.fetchSettings();

  initializeDateFormatting('sk_SK').then((_) => runApp(MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NewsProvider>.value(
          value: NewsProvider(),
        ),
        ChangeNotifierProvider<EventsProvider>.value(
          value: EventsProvider(),
        ),
        ChangeNotifierProvider<FestivalProvider>.value(
          value: FestivalProvider(),
        ),
        ChangeNotifierProvider<InfoProvider>.value(
          value: InfoProvider(),
        ),
        ChangeNotifierProvider<ArrangementProvider>.value(
          value: ArrangementProvider(),
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
                  //fontWeight: FontWeight.bold,
                  color: darkColor),
              bodyLarge: TextStyle(fontSize: 14.0, color: darkColor),
              bodyMedium: TextStyle(fontSize: 14.0, color: darkColor),
            )),
        darkTheme: ThemeData(useMaterial3: true, colorScheme: darkColorScheme),

        debugShowCheckedModeBanner: false,
        //home: TabPage(),
        routerConfig: _router,
      ),
    );
  }
}
