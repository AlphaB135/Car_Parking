import 'package:flutter/material.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;

  const BottomNavigation({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _navigateToScreen(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF4285F4),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'ลานจอดรถ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'แผนที่',
          ),
        ],
      ),
    );
  }

  void _navigateToScreen(BuildContext context, int index) {
    switch (index) {
      case 0:
        if (ModalRoute.of(context)?.settings.name != '/home') {
          Navigator.pushReplacementNamed(context, '/home');
        }
        break;
      case 1:
        if (ModalRoute.of(context)?.settings.name != '/parking-selection' &&
            ModalRoute.of(context)?.settings.name != '/parking-detail') {
          Navigator.pushReplacementNamed(context, '/parking-selection');
        }
        break;
      case 2:
        if (ModalRoute.of(context)?.settings.name != '/parking-map') {
          Navigator.pushReplacementNamed(context, '/parking-map');
        }
        break;
    }
  }
}
