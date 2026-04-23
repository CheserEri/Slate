import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/photo_service.dart';

final localPhotosProvider =
    StateNotifierProvider<LocalPhotosNotifier, AsyncValue<List<MediaItem>>>(
  (ref) => LocalPhotosNotifier(),
);

class LocalPhotosNotifier extends StateNotifier<AsyncValue<List<MediaItem>>> {
  LocalPhotosNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final photos = await PhotoService.getRecentPhotos(count: 500);
      state = AsyncValue.data(photos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final selectedPhotosProvider = StateProvider<Set<String>>((ref) => {});
final isMultiSelectProvider = StateProvider<bool>((ref) => false);

void toggleMultiSelect(WidgetRef ref) {
  final current = ref.read(isMultiSelectProvider);
  ref.read(isMultiSelectProvider.notifier).state = !current;
  if (!current == false) {
    ref.read(selectedPhotosProvider.notifier).state = {};
  }
}

void togglePhotoSelection(WidgetRef ref, String id) {
  final current = Set<String>.from(ref.read(selectedPhotosProvider));
  if (current.contains(id)) {
    current.remove(id);
  } else {
    current.add(id);
  }
  ref.read(selectedPhotosProvider.notifier).state = current;
}
