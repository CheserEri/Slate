import 'package:flutter_test/flutter_test.dart';
import 'package:slate_app/utils/smb_form_logic.dart';

void main() {
  group('SmbFormLogic', () {
    test('normalizes root path to SMB relative format', () {
      expect(SmbFormLogic.normalizeRootPath(r'/Cloud\MiGallery/'), 'Cloud/MiGallery');
      expect(SmbFormLogic.normalizeRootPath(r'\\Cloud\\MiGallery\\'), 'Cloud/MiGallery');
      expect(SmbFormLogic.normalizeRootPath(''), '');
    });

    test('requires host and share before save is enabled', () {
      final empty = SmbFormDraft();
      expect(SmbFormLogic.canSave(empty), isFalse);

      final onlyHost = SmbFormDraft(host: '10.147.20.50');
      expect(SmbFormLogic.canSave(onlyHost), isFalse);

      final ready = SmbFormDraft(
        host: '10.147.20.50',
        share: 'MyDoc',
        username: 'naeuta',
      );
      expect(SmbFormLogic.canSave(ready), isTrue);
    });

    test('requires host before listing shares and host+share before browsing root path', () {
      expect(SmbFormLogic.canBrowseShares(const SmbFormDraft()), isFalse);
      expect(SmbFormLogic.canBrowseShares(const SmbFormDraft(host: '10.147.20.50')), isTrue);

      expect(
        SmbFormLogic.canBrowseRootPath(const SmbFormDraft(host: '10.147.20.50')),
        isFalse,
      );
      expect(
        SmbFormLogic.canBrowseRootPath(
          const SmbFormDraft(host: '10.147.20.50', share: 'MyDoc'),
        ),
        isTrue,
      );
    });

    test('builds a friendly default display name when user leaves name blank', () {
      expect(
        SmbFormLogic.resolveDisplayName(
          const SmbFormDraft(host: '10.147.20.50', share: 'MyDoc', rootPath: 'Cloud/MiGallery'),
        ),
        'MiGallery',
      );

      expect(
        SmbFormLogic.resolveDisplayName(
          const SmbFormDraft(host: '10.147.20.50', share: 'MyDoc'),
        ),
        'MyDoc',
      );
    });
  });
}
