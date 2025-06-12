class Task {

  final String title;
  final DateTime? reminder;
  Task({required this.reminder,required this.title});

}

class CrudOperations {
  List<Task> tasks=[];
  
  void create_task(String task,{DateTime? datetime}){
     tasks.add(Task(reminder: datetime, title: task));
  }

  void delete_task(int index){
    if (index>=0 && index<tasks.length){
      tasks.removeAt(index);
    }
  
  }
  List<Task> get_tasks(){
    return tasks;
  }
  
}

