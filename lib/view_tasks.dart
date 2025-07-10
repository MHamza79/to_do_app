import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // assumes notificationsPlugin is defined in main.dart

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle the notification tap in background
  debugPrint(
    'Notification (background) tapped: ${notificationResponse.payload}',
  );
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({Key? key}) : super(key: key); // Added const constructor

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  TextEditingController taskController = TextEditingController();
  DateTime? reminderTime;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's email for Firebase structure
  String? get currentUserEmail => _auth.currentUser?.email;

  Future<void> _checkNotificationPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      final bool? areNotificationsEnabled =
          await androidImplementation.areNotificationsEnabled();
      debugPrint('Notifications enabled: $areNotificationsEnabled');

      if (areNotificationsEnabled == false) {
        // Show a dialog to guide user to enable notifications
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Notifications Disabled'),
                  content: const Text(
                    'Please enable notifications in your device settings to receive task reminders.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();
    _checkNotificationPermissions();
  }

  @override
  void dispose() {
    taskController.dispose(); // Dispose the controller
    super.dispose();
  }

  Future<void> _requestNotificationPermissions() async {
    // Request notification permissions for Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      final bool? granted =
          await androidImplementation.requestNotificationsPermission();
      debugPrint('Notification permission granted: $granted');
    }
  }

  Future<void> scheduleNotification(
    String title,
    DateTime scheduledTime,
  ) async {
    try {
      // Generate a unique ID based on timestamp and title hash
      final int notificationId = scheduledTime.millisecondsSinceEpoch ~/ 1000;

      // Convert to timezone-aware datetime
      final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      // Check if the scheduled time is in the past
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint(
          'Cannot schedule notification for past time: $scheduledDate',
        );
        return;
      }

      await notificationsPlugin.zonedSchedule(
        notificationId, // Unique ID
        title, // Notification Title
        'Reminder!', // Notification Body
        scheduledDate, // Schedule time
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel', // Channel ID
            'Task Reminders', // Channel Name
            importance: Importance.max,
            priority: Priority.high,
            color: Colors.teal,
            icon: '@mipmap/ic_launcher',
            channelShowBadge: true,
            enableVibration: true,
            playSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint(
        'Notification scheduled for: $scheduledDate with ID: $notificationId',
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> cancelNotification(int notificationId) async {
    await notificationsPlugin.cancel(notificationId);
    debugPrint('Notification cancelled with ID: $notificationId');
  }

  Future<void> saveTaskToFirebase(String title, DateTime? time) async {
    if (title.isEmpty || currentUserEmail == null) return;

    // Create a user-specific collection path
    final userTasksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserEmail)
        .collection('tasks');

    final docRef = await userTasksRef.add({
      'title': title,
      'reminder': time?.toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (time != null) {
      // Store the notification ID in Firestore for later cancellation
      final int notificationId = time.millisecondsSinceEpoch ~/ 1000;
      await userTasksRef.doc(docRef.id).update({
        'notificationId': notificationId,
      });
      await scheduleNotification(title, time);
    }
  }

  Future<void> pickReminder(BuildContext context) async {
    // Ensuring the theme for date and time pickers matches the new design
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder:
          (context, child) => Theme(
            data: ThemeData.light().copyWith(
              // Changed to light theme
              colorScheme: ColorScheme.light(
                primary: Colors.blueAccent, // Header background color
                onPrimary: Colors.white, // Header text color
                onSurface: Colors.blueGrey.shade800, // Date text color
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal, // OK/Cancel button color
                ),
              ),
            ),
            child: child!,
          ),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder:
          (context, child) => Theme(
            data: ThemeData.light().copyWith(
              // Changed to light theme
              colorScheme: ColorScheme.light(
                primary: Colors.blueAccent, // Header background color
                onPrimary: Colors.white, // Header text color
                onSurface: Colors.blueGrey.shade800, // Time text color
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal, // OK/Cancel button color
                ),
              ),
            ),
            child: child!,
          ),
    );
    if (time == null) return;

    setState(() {
      // Added setState to update UI when reminderTime changes
      reminderTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _showTestNotification() async {
    try {
      await notificationsPlugin.show(
        999, // Test notification ID
        'Test Notification',
        'Notifications are working! You can now set reminders for your tasks.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel',
            'Task Reminders',
            importance: Importance.max,
            priority: Priority.high,
            color: Colors.teal,
            icon: '@mipmap/ic_launcher',
            channelShowBadge: true,
            enableVibration: true,
            playSound: true,
          ),
        ),
      );
      debugPrint('Test notification sent successfully');
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  Future<void> _scheduleTestNotification() async {
    try {
      final now = DateTime.now();
      final scheduledTime = now.add(
        const Duration(seconds: 5),
      ); // 5 seconds from now

      await notificationsPlugin.zonedSchedule(
        888, // Test scheduled notification ID
        'Scheduled Test',
        'This notification was scheduled 5 seconds ago!',
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel',
            'Task Reminders',
            importance: Importance.max,
            priority: Priority.high,
            color: Colors.teal,
            icon: '@mipmap/ic_launcher',
            channelShowBadge: true,
            enableVibration: true,
            playSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint('Test scheduled notification set for: $scheduledTime');
    } catch (e) {
      debugPrint('Error scheduling test notification: $e');
    }
  }

  Future<void> _comprehensiveNotificationTest() async {
    try {
      // Test 1: Immediate notification
      await notificationsPlugin.show(
        1001,
        'Immediate Test',
        'This notification appears immediately',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel',
            'Task Reminders',
            importance: Importance.max,
            priority: Priority.high,
            color: Colors.teal,
            icon: '@mipmap/ic_launcher',
            channelShowBadge: true,
            enableVibration: true,
            playSound: true,
          ),
        ),
      );

      // Test 2: Scheduled notification for 10 seconds
      final now = DateTime.now();
      final scheduledTime = now.add(const Duration(seconds: 10));

      await notificationsPlugin.zonedSchedule(
        1002,
        'Scheduled Test (10s)',
        'This notification was scheduled 10 seconds ago',
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel',
            'Task Reminders',
            importance: Importance.max,
            priority: Priority.high,
            color: Colors.teal,
            icon: '@mipmap/ic_launcher',
            channelShowBadge: true,
            enableVibration: true,
            playSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      // Test 3: Scheduled notification for 1 minute
      final oneMinuteLater = now.add(const Duration(minutes: 1));

      await notificationsPlugin.zonedSchedule(
        1003,
        'Scheduled Test (1min)',
        'This notification was scheduled 1 minute ago',
        tz.TZDateTime.from(oneMinuteLater, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel',
            'Task Reminders',
            importance: Importance.max,
            priority: Priority.high,
            color: Colors.teal,
            icon: '@mipmap/ic_launcher',
            channelShowBadge: true,
            enableVibration: true,
            playSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint('Comprehensive notification test completed successfully');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification test completed! Check for 3 notifications.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in comprehensive notification test: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification test failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  Future<void> _showNotificationStatus() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      final bool? areNotificationsEnabled =
          await androidImplementation.areNotificationsEnabled();

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Notification Status'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications Enabled: ${areNotificationsEnabled ?? "Unknown"}',
                    ),
                    const SizedBox(height: 10),
                    const Text('Channel: Task Reminders'),
                    const Text('Importance: Maximum'),
                    const Text('Priority: High'),
                    const Text('Vibration: Enabled'),
                    const Text('Sound: Enabled'),
                    const SizedBox(height: 10),
                    const Text('Test buttons available in app bar:'),
                    const Text('• Bell icon: Immediate test'),
                    const Text('• Clock icon: 5-second test'),
                    const Text('• Notification icon: Comprehensive test'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.blueGrey.shade50, // Lighter background for the entire screen
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your To-Do List",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (currentUserEmail != null)
              Text(
                currentUserEmail!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.teal, // Consistent app bar color
        centerTitle: true,
        elevation: 4, // Add subtle shadow to app bar
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showNotificationStatus,
            tooltip: 'Notification Status',
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: _showTestNotification,
            tooltip: 'Immediate Test',
          ),
          IconButton(
            icon: const Icon(Icons.schedule, color: Colors.white),
            onPressed: _scheduleTestNotification,
            tooltip: '5-Second Test',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: _comprehensiveNotificationTest,
            tooltip: 'Comprehensive Test',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body:
          currentUserEmail == null
              ? const Center(
                child: Text(
                  'Please sign in to view your tasks',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
              : StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserEmail)
                        .collection('tasks')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.teal),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 80,
                            color: Colors.blueGrey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks yet! Add one below.',
                            style: TextStyle(
                              color: Colors.blueGrey.shade600,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final tasks = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final title =
                          task['title'] as String; // Ensure type safety
                      final reminder = task['reminder'] as String?;

                      final formattedReminder =
                          reminder != null
                              ? DateFormat.yMMMd().add_jm().format(
                                DateTime.parse(reminder),
                              ) // More readable format
                              : null;

                      return Card(
                        elevation: 4, // Added elevation for card effect
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            15,
                          ), // Rounded corners
                        ),
                        color: Colors.white, // White background for task cards
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 5.0,
                          ), // Adjust padding
                          child: ListTile(
                            title: Text(
                              title,
                              style: TextStyle(
                                color:
                                    Colors
                                        .blueGrey
                                        .shade800, // Darker text for title
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle:
                                formattedReminder != null
                                    ? Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.alarm,
                                            size: 16,
                                            color: Colors.blueAccent.shade400,
                                          ), // Alarm icon
                                          const SizedBox(width: 5),
                                          Text(
                                            'Remind at: $formattedReminder',
                                            style: TextStyle(
                                              color: Colors.blueAccent.shade700,
                                              fontSize: 13,
                                            ), // Reminder text color
                                          ),
                                        ],
                                      ),
                                    )
                                    : null,
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ), // Red delete icon
                              onPressed: () async {
                                final notificationId =
                                    task['notificationId'] as int?;
                                if (notificationId != null) {
                                  await cancelNotification(notificationId);
                                }
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUserEmail)
                                    .collection('tasks')
                                    .doc(task.id)
                                    .delete();
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal, // Vibrant FAB color
        foregroundColor: Colors.white,
        onPressed: () async {
          taskController.clear();
          setState(() {
            // Update state when opening dialog
            reminderTime = null; // Clear reminder time for new task
          });

          await showDialog(
            context: context,
            builder:
                (context) => StatefulBuilder(
                  // Use StatefulBuilder for dialog state management
                  builder: (context, setState) {
                    // Local setState for the dialog
                    return AlertDialog(
                      backgroundColor: Colors.white, // White dialog background
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ), // Rounded dialog corners
                      title: Text(
                        'Add New Task',
                        style: TextStyle(
                          color: Colors.blueGrey.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: taskController,
                            style: TextStyle(color: Colors.blueGrey.shade800),
                            decoration: InputDecoration(
                              labelText: 'Task Title',
                              labelStyle: TextStyle(
                                color: Colors.blueGrey.shade500,
                              ),
                              hintText: 'e.g., Buy groceries', // Hint text
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor:
                                  Colors.grey.shade100, // Light fill color
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.teal,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(
                                Icons.lightbulb_outline,
                                color: Colors.blueAccent,
                              ), // Icon for task title
                            ),
                          ),
                          const SizedBox(height: 15),
                          // Display selected reminder time or "Pick Reminder"
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              reminderTime == null
                                  ? 'No reminder set'
                                  : 'Reminder: ${DateFormat.yMMMd().add_jm().format(reminderTime!)}',
                              style: TextStyle(
                                color: Colors.blueGrey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity, // Make button fill width
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await pickReminder(
                                  context,
                                ); // Call the original pickReminder
                                setState(
                                  () {},
                                ); // Update the dialog's state to show selected time
                              },
                              icon: const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Set Reminder',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors
                                        .blueAccent, // Button color for reminder
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.blueGrey),
                          ), // Cancel button color
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await saveTaskToFirebase(
                              taskController.text,
                              reminderTime,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal, // Save button color
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Add Task',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  },
                ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
