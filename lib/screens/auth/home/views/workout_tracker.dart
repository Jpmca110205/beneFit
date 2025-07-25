
import 'package:flutter/material.dart';
import 'package:game/screens/auth/widgets/start_workout_button.dart';
import 'package:game/screens/auth/widgets/add_workout_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game/screens/auth/widgets/exercise.dart';


class WorkoutTrackerScreen extends StatefulWidget {
  const WorkoutTrackerScreen({super.key});

  @override
  State<WorkoutTrackerScreen> createState() => _WorkoutTrackerScreenState();
}

  String formatTime(int seconds) {
  final minutes = seconds ~/ 60;
  final secs = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

class _WorkoutTrackerScreenState extends State<WorkoutTrackerScreen> {
  bool isLoading = false;
  List<WorkoutStats> workouts = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    loadWorkouts();
  }


  Future<void> updateWorkoutInFirebase(String workoutId, List<Exercise> updatedExercises) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final workoutRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts')
        .doc(workoutId);

    await workoutRef.update({
      'exercises': updatedExercises.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> loadWorkouts() async {
    setState(() => isLoading = true);
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts')
        .get();

    List<WorkoutStats> loadedWorkouts = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();

      if (data['name'] != null && data['description'] != null) {
        try {
          loadedWorkouts.add(WorkoutStats.fromMap(data, doc.id));
        } catch (e) {
          print('Invalid workout format for doc ${doc.id}: $e');
        }
      } else {
        print('Skipping empty/malformed workout: ${doc.id}');
      }
    }

    setState(() {
      workouts = loadedWorkouts;
      isLoading = false;
    });
  }


  Future<void> saveWorkout(WorkoutStats workout) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final workoutData = workout.toMap();

    if (workout.id == null) {
      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .add(workoutData);

      workout.id = docRef.id;
    } else {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .doc(workout.id)
          .set(workoutData);
    }
  }

  Future<void> deleteWorkout(WorkoutStats workout) async {
    final user = _auth.currentUser;
    if (user == null || workout.id == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .doc(workout.id)
          .delete();
    } catch (e) {
      print('Failed to delete workout: $e');
    }
  }

  void addToWorkout(WorkoutStats newWorkout) {
    setState(() {
      workouts.add(newWorkout);
    });
    saveWorkout(newWorkout);
  }

  // When workout finishes, increment counters and save to Firebase
void onWorkoutFinished(WorkoutStats updatedWorkout, int secondsElapsed) {
  setState(() {
    updatedWorkout.timesCompleted++;
    updatedWorkout.daysSinceLast = 0;
  });
  saveWorkout(updatedWorkout);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Updated workout: ${updatedWorkout.name} \n Time Elapsed: ${formatTime(secondsElapsed)}')),
  );
}




  void _editWorkout(int index) {
    final nameController = TextEditingController(text: workouts[index].name);
    final descriptionController =
        TextEditingController(text: workouts[index].description);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Workout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  workouts[index].name = nameController.text;
                  workouts[index].description = descriptionController.text;
                });
                saveWorkout(workouts[index]);
                Navigator.of(context).pop();
                
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await deleteWorkout(workouts[index]);
                setState(() {
                  workouts.removeAt(index);
                });
                Navigator.of(context).pop();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 70),
                const Text(
                  'Workout Tracker',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 40),
                if (workouts.isEmpty)
                  const Text(
                    'No workouts yet. Tap below to add one!',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ...workouts.asMap().entries.map((entry) {
                  int index = entry.key;
                  WorkoutStats workout = entry.value;

                  return GestureDetector(
                    onTap: () => _editWorkout(index),
                    child: Container(
                      width: 350,
                      height: 220,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              workout.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  workout.description,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Times Completed: ${workout.timesCompleted}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Days Since Last: ${workout.daysSinceLast}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                StartWorkoutButton(
                                  workout: workout,
                                  onWorkoutFinished: (secondsElapsed) => onWorkoutFinished(workout, secondsElapsed),

                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 20),
                AddWorkoutButton(onWorkoutAdded: addToWorkout),
                const SizedBox(height: 150),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Your model class remains the same:
class WorkoutStats {
  String? id;
  String name;
  String description;
  int timesCompleted;
  int daysSinceLast;
  List<Exercise> exercises;

  WorkoutStats({
    this.id,
    required this.name,
    required this.description,
    required this.timesCompleted,
    required this.daysSinceLast,
    required this.exercises,
  });

  factory WorkoutStats.fromMap(Map<String, dynamic> map, String id) {
    if (map['name'] == null || map['description'] == null) {
      throw FormatException('Missing required fields in workout map');
    }

    return WorkoutStats(
      id: id,
      name: map['name'],
      description: map['description'],
      timesCompleted: map['timesCompleted'] ?? 0,
      daysSinceLast: map['daysSinceLast'] ?? 0,
      exercises: (map['exercises'] as List<dynamic>? ?? [])
          .map((e) => Exercise.fromMap(e))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'timesCompleted': timesCompleted,
      'daysSinceLast': daysSinceLast,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }
}
