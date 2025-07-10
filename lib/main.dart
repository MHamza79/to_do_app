import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:to_do_app/signup.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:to_do_app/view_tasks.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle the notification tap in background
  debugPrint(
    'Notification (background) tapped: ${notificationResponse.payload}',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize timezone
  tz.initializeTimeZones();

  // Create notification channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'task_channel', // Channel ID
    'Task Reminders', // Channel Name
    description:
        'Channel for task reminder notifications', // Channel Description
    importance: Importance.max,
  );

  // Create the Android notification channel
  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await notificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (notificationResponse) async {
      debugPrint('Foreground tap: ${notificationResponse.payload}');
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/auth': (context) => const AuthPage(),
        '/tasks': (context) => const TaskScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // User is signed in
          return const TaskScreen();
        } else {
          // User is not signed in
          return const AuthPage();
        }
      },
    );
  }
}
