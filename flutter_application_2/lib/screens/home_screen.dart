import 'package:flutter/material.dart';
import 'mochimon_screen.dart';
import 'study_screen.dart';
import 'communication_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    const MochimonScreen(),
    const StudyScreen(),
    const CommunicationScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'ムチモン',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: '勉強する',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'コミュニティー',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
