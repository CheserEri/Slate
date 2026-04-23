import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transfer_provider.dart';
import 'photos_screen.dart';
import 'albums_screen.dart';
import 'smb_screen.dart';
import 'transfers_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  final _screens = const [
    PhotosScreen(),
    AlbumsScreen(),
    SmbScreen(),
    TransfersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeCount = ref.watch(activeTransferCountProvider);

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: '照片',
          ),
          const NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '相册',
          ),
          const NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'SMB',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.swap_vert_outlined),
            ),
            selectedIcon: const Icon(Icons.swap_vert),
            label: '传输',
          ),
        ],
      ),
    );
  }
}
