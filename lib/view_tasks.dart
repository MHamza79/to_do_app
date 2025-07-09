import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'main.dart'; // assumes notificationsPlugin is defined in main.dart

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle the notification tap in background
  debugPrint('Notification (background) tapped: ${notificationResponse.payload}');
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({Key? key}) : super(key: key); // Added const constructor

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  TextEditingController taskController = TextEditingController();
  DateTime? reminderTime;

  @override
  void dispose() {
    taskController.dispose(); // Dispose the controller
    super.dispose();
  }

  Future<void> scheduleNotification(String title, DateTime scheduledTime) async {
    // This function had a duplicate definition. Keeping the outer one.
    await notificationsPlugin.zonedSchedule(
      scheduledTime.millisecondsSinceEpoch ~/ 1000, // Unique ID
      title, // Notification Title
      'Reminder!', // Notification Body
      tz.TZDateTime.from(scheduledTime, tz.local), // Schedule time

      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel', // Channel ID
          'Task Reminders', // Channel Name
          importance: Importance.max,
          priority: Priority.high,
          color: Colors.teal,
          icon: '@mipmap/ic_launcher',
        ),
      ),

      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,

      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> saveTaskToFirebase(String title, DateTime? time) async {
    if (title.isEmpty) return;

    await FirebaseFirestore.instance.collection('tasks').add({
      'title': title,
      'reminder': time?.toIso8601String(),
    });

    if (time != null) {
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
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith( // Changed to light theme
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
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith( // Changed to light theme
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

    setState(() { // Added setState to update UI when reminderTime changes
      reminderTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50, // Lighter background for the entire screen
      appBar: AppBar(
        title: const Text(
          "Your To-Do List", // Updated title
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal, // Consistent app bar color
        centerTitle: true,
        elevation: 4, // Add subtle shadow to app bar
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tasks').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.blueGrey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No tasks yet! Add one below.',
                    style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 18),
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
              final title = task['title'] as String; // Ensure type safety
              final reminder = task['reminder'] as String?;

              final formattedReminder = reminder != null
                  ? DateFormat.yMMMd().add_jm().format(DateTime.parse(reminder)) // More readable format
                  : null;

              return Card(
                elevation: 4, // Added elevation for card effect
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15), // Rounded corners
                ),
                color: Colors.white, // White background for task cards
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0), // Adjust padding
                  child: ListTile(
                    title: Text(
                      title,
                      style: TextStyle(
                        color: Colors.blueGrey.shade800, // Darker text for title
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: formattedReminder != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.alarm, size: 16, color: Colors.blueAccent.shade400), // Alarm icon
                                const SizedBox(width: 5),
                                Text(
                                  'Remind at: $formattedReminder',
                                  style: TextStyle(color: Colors.blueAccent.shade700, fontSize: 13), // Reminder text color
                                ),
                              ],
                            ),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent), // Red delete icon
                      onPressed: () =>
                          FirebaseFirestore.instance.collection('tasks').doc(task.id).delete(),
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
          setState(() { // Update state when opening dialog
            reminderTime = null; // Clear reminder time for new task
          });

          await showDialog(
            context: context,
            builder: (context) => StatefulBuilder( // Use StatefulBuilder for dialog state management
              builder: (context, setState) { // Local setState for the dialog
                return AlertDialog(
                  backgroundColor: Colors.white, // White dialog background
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Rounded dialog corners
                  title: Text(
                    'Add New Task',
                    style: TextStyle(color: Colors.blueGrey.shade800, fontWeight: FontWeight.bold),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: taskController,
                        style: TextStyle(color: Colors.blueGrey.shade800),
                        decoration: InputDecoration(
                          labelText: 'Task Title',
                          labelStyle: TextStyle(color: Colors.blueGrey.shade500),
                          hintText: 'e.g., Buy groceries', // Hint text
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.grey.shade100, // Light fill color
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.teal, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: Icon(Icons.lightbulb_outline, color: Colors.blueAccent), // Icon for task title
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
                          style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity, // Make button fill width
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await pickReminder(context); // Call the original pickReminder
                            setState(() {}); // Update the dialog's state to show selected time
                          },
                          icon: const Icon(Icons.calendar_today, color: Colors.white),
                          label: const Text(
                            'Set Reminder',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent, // Button color for reminder
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey)), // Cancel button color
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await saveTaskToFirebase(taskController.text, reminderTime);
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, // Save button color
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Add Task', style: TextStyle(color: Colors.white)),
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