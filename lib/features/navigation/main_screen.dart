import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home/views/home_view.dart';
import '../home/viewmodels/home_viewmodel.dart';
import '../catalog/views/catalog_view.dart';
import '../catalog/viewmodels/catalog_viewmodel.dart';
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

  void _onTabTap(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const PostView(),
        ),
      ).then((result) {
        if (!mounted) return;
        context.read<HomeViewModel>().loadHomeData();
        context.read<CatalogViewModel>().loadProducts();
        if (result == true) {
          setState(() => _currentIndex = 0);
        }
      });
      return;
    }
    if (index == 0 && _currentIndex != 0) {
      context.read<HomeViewModel>().loadHomeData();
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeView(),
          CatalogView(),
          SizedBox.shrink(),
          FavoritesView(),
          ProfileView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.onSurface,
        unselectedItemColor: const Color(0xFF99944D),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/home.png',
              width: 24,
              height: 24,
              color: _currentIndex == 0
                  ? Theme.of(context).colorScheme.onSurface
                  : null,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/catalog.png',
              width: 24,
              height: 24,
              color: _currentIndex == 1
                  ? Theme.of(context).colorScheme.onSurface
                  : null,
            ),
            label: 'Catalog',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/post.png',
              width: 24,
              height: 24,
              color: _currentIndex == 2
                  ? Theme.of(context).colorScheme.onSurface
                  : null,
            ),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/favorites.png',
              width: 24,
              height: 24,
              color: _currentIndex == 3
                  ? Theme.of(context).colorScheme.onSurface
                  : null,
            ),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/profile.png',
              width: 24,
              height: 24,
              color: _currentIndex == 4
                  ? Theme.of(context).colorScheme.onSurface
                  : null,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
