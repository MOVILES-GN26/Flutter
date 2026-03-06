import 'package:flutter/material.dart';
import '../home/views/home_view.dart';
import '../catalog/views/catalog_view.dart';
import '../post/views/post_view.dart';
import '../favorites/views/favorites_view.dart';
import '../profile/views/profile_view.dart';

/// Pantalla principal con bottom navigation bar
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeView(),
    CatalogView(),
    PostView(),
    FavoritesView(),
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: const Color(0xFF99944D),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/home.png',
              width: 24,
              height: 24,
              color: _currentIndex == 0 ? Colors.black : null,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/catalog.png',
              width: 24,
              height: 24,
              color: _currentIndex == 1 ? Colors.black : null,
            ),
            label: 'Catalog',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/post.png',
              width: 24,
              height: 24,
              color: _currentIndex == 2 ? Colors.black : null,
            ),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/favorites.png',
              width: 24,
              height: 24,
              color: _currentIndex == 3 ? Colors.black : null,
            ),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/profile.png',
              width: 24,
              height: 24,
              color: _currentIndex == 4 ? Colors.black : null,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
