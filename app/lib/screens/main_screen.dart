import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transfer_provider.dart';
import '../widgets/glass_container.dart';
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
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: _screens[_selectedIndex],
      bottomNavigationBar: GlassBottomBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          const GlassNavItem(
            icon: Icon(Icons.photo_library_outlined, size: 24),
            selectedIcon: Icon(Icons.photo_library, size: 24),
            label: '照片',
          ),
          const GlassNavItem(
            icon: Icon(Icons.folder_outlined, size: 24),
            selectedIcon: Icon(Icons.folder, size: 24),
            label: '相册',
          ),
          const GlassNavItem(
            icon: Icon(Icons.cloud_outlined, size: 24),
            selectedIcon: Icon(Icons.cloud, size: 24),
            label: 'SMB',
          ),
          GlassNavItem(
            icon: activeCount > 0
                ? Badge(
                    isLabelVisible: true,
                    label: Text('$activeCount',
                        style: const TextStyle(fontSize: 10)),
                    child: const Icon(Icons.swap_vert_outlined, size: 24),
                  )
                : const Icon(Icons.swap_vert_outlined, size: 24),
            selectedIcon: const Icon(Icons.swap_vert, size: 24),
            label: '传输',
          ),
        ],
      ),
    );
  }
}
