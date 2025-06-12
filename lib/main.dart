import 'package:flutter/material.dart';
import 'package:to_do_app/crud_operations.dart';
import 'package:to_do_app/view_tasks.dart';

void main() {
  runApp( MainApp());
}
class MainApp extends StatelessWidget{
  
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      debugShowCheckedModeBanner: false,
home: ViewTasks(TaskManager: CrudOperations(),),
    );

  }
}

