import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Aquarium',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class Fish {
  Color color;
  double speed;
  Offset position;
  bool isGrowing;

  Fish({required this.color, required this.speed, this.position = Offset.zero, this.isGrowing = true});
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  List<Fish> fishList = [];
  Color selectedColor = Colors.blue;
  double selectedSpeed = 1.0;
  bool collisionEnabled = true;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)
      ..repeat()
      ..addListener(() {
        _updateFishPositions();
      });
    _loadSettings();
  }

  void _updateFishPositions() {
    setState(() {
      for (var fish in fishList) {
        fish.position = Offset(
          (fish.position.dx + fish.speed * (Random().nextBool() ? 1 : -1)) % 300,
          (fish.position.dy + fish.speed * (Random().nextBool() ? 1 : -1)) % 300,
        );

        if (collisionEnabled) {
          _checkForCollisions();
        }

        if (fish.isGrowing) {
          fish.isGrowing = false;  // Fish stop growing after being added.
        }
      }
    });
  }

  void _checkForCollisions() {
    for (int i = 0; i < fishList.length; i++) {
      for (int j = i + 1; j < fishList.length; j++) {
        Fish fish1 = fishList[i];
        Fish fish2 = fishList[j];

        if ((fish1.position - fish2.position).distance < 20) {
          fish1.speed = -fish1.speed;
          fish2.speed = -fish2.speed;

          setState(() {
            fish1.color = Random().nextBool() ? Colors.red : Colors.green;
            fish2.color = Random().nextBool() ? Colors.blue : Colors.yellow;
          });
        }
      }
    }
  }

  void _addFish() {
    if (fishList.length < 10) {
      setState(() {
        fishList.add(Fish(color: selectedColor, speed: selectedSpeed, position: Offset(150, 150)));
      });
    }
  }

  Future<void> _saveSettings() async {
    final database = openDatabase(join(await getDatabasesPath(), 'aquarium.db'), version: 1,
        onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE settings(id INTEGER PRIMARY KEY, fishCount INTEGER, speed REAL, color TEXT)',
      );
    });

    final db = await database;
    await db.insert(
      'settings',
      {'fishCount': fishList.length, 'speed': selectedSpeed, 'color': selectedColor.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _loadSettings() async {
    final database = openDatabase(join(await getDatabasesPath(), 'aquarium.db'), version: 1);
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query('settings');

    if (maps.isNotEmpty) {
      setState(() {
        selectedSpeed = maps.first['speed'];
        selectedColor = Color(int.parse(maps.first['color'].replaceAll('Color(', '').replaceAll(')', '')));
        for (int i = 0; i < maps.first['fishCount']; i++) {
          _addFish();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Aquarium'),
        actions: [
          IconButton(onPressed: _saveSettings, icon: const Icon(Icons.save)),
          Switch(
              value: collisionEnabled,
              onChanged: (val) {
                setState(() {
                  collisionEnabled = val;
                });
              })
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 300,
            height: 300,
            color: Colors.lightBlueAccent,
            child: Stack(
              children: fishList
                  .map((fish) => Positioned(
                        left: fish.position.dx,
                        top: fish.position.dy,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: fish.isGrowing ? 30 : 20,
                          height: fish.isGrowing ? 30 : 20,
                          decoration: BoxDecoration(
                            color: fish.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Slider(
            value: selectedSpeed,
            min: 0.1,
            max: 5.0,
            onChanged: (value) {
              setState(() {
                selectedSpeed = value;
              });
            },
            label: 'Speed: $selectedSpeed',
          ),
          DropdownButton<Color>(
            value: selectedColor,
            items: [Colors.red, Colors.green, Colors.blue].map((Color color) {
              return DropdownMenuItem<Color>(
                value: color,
                child: Container(
                  width: 24,
                  height: 24,
                  color: color,
                ),
              );
            }).toList(),
            onChanged: (Color? newValue) {
              setState(() {
                selectedColor = newValue!;
              });
            },
          ),
          ElevatedButton(onPressed: _addFish, child: const Text('Add Fish')),
        ],
      ),
    );
  }
}
