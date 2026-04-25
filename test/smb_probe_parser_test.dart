import 'package:test/test.dart';
import 'package:slate/services/smb_probe_parser.dart';

void main() {
  group('smb probe parser', () {
    test('extracts disk shares from grepable smbclient output', () {
      const output = '''
Disk|print\$|Printer Drivers
Disk|MyDoc|
Disk|DiskRoot|
IPC|IPC\$|IPC Service
SMB1 disabled -- no workgroup available
''';

      expect(parseDiskShares(output), ['print' r'$', 'MyDoc', 'DiskRoot']);
    });

    test('normalizes relative smb paths for root picker', () {
      expect(normalizeRelativeSmbPath(r'/Cloud\\MiGallery/'), 'Cloud/MiGallery');
      expect(normalizeRelativeSmbPath('Cloud///Album'), 'Cloud/Album');
      expect(normalizeRelativeSmbPath(''), '');
    });
  });
}
