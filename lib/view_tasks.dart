import 'package:flutter/material.dart';
import 'package:to_do_app/crud_operations.dart';

class ViewTasks extends StatefulWidget {
  final CrudOperations TaskManager;

  const ViewTasks({super.key, required this.TaskManager});

  @override
  State<ViewTasks> createState() => _ViewTasksState();
}

class _ViewTasksState extends State<ViewTasks> {
  late List<Task> tasks;
  TextEditingController taskInput = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    tasks = widget.TaskManager.get_tasks();
  }

  Future<void> pickDate() async {
    selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );
  }

  Future<void> pickTime() async {
    selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
  }

  DateTime? combineDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    double Width = MediaQuery.of(context).size.width;
    double Height = MediaQuery.of(context).size.height;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('TO DO APP'),
          centerTitle: true,
          backgroundColor: const Color.fromARGB(255, 192, 188, 188),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                  left: Width * 0.2, top: Height * 0.02, right: Width * 0.2),
              child: Container(
                height: 400,
                child: ListView.separated(
                  separatorBuilder: (context, index) => SizedBox(height: 10,),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return ListTile(
                    
                      tileColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.black87),
                      ),
                      title: Text(task.title),
                      subtitle: task.reminder != null
                          ? Text("Reminder: ${task.reminder}")
                          : null,
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            widget.TaskManager.delete_task(index);
                            tasks = widget.TaskManager.get_tasks();
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: Colors.grey[300],
                  title: Row(
                    children: [
                      Text('Add Task'),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.alarm),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("Add date and time"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                        onPressed: pickDate,
                                        child: Text("Pick Date")),
                                    TextButton(
                                        onPressed: pickTime,
                                        child: Text("Pick Time")),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      )
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: taskInput,
                        decoration:
                            InputDecoration(labelText: 'Enter Task'),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: () {
                              final DateTime? fullReminder =
                                  combineDateTime(selectedDate, selectedTime);
                              setState(() {
                                widget.TaskManager.create_task(
                                  taskInput.text,
                                  datetime: fullReminder,
                                );
                                tasks = widget.TaskManager.get_tasks();
                                taskInput.clear();
                                selectedDate = null;
                                selectedTime = null;
                              });
                              Navigator.pop(context);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
