class ApiConstants {
  // Override at build/run time with:
  // flutter run --dart-define=SLATE_BASE_URL=http://10.0.2.2:8080
  // flutter build apk --dart-define=SLATE_BASE_URL=http://10.147.20.50:8080
  static const String baseUrl = String.fromEnvironment(
    'SLATE_BASE_URL',
    defaultValue: 'http://10.147.20.50:8080',
  );

  static String get localAlbums => '$baseUrl/local/albums';
  static String localItems(String path) => '$baseUrl/local/albums/$path/items';
  static String get smbServers => '$baseUrl/smb/servers';
  static String smbServer(String id) => '$baseUrl/smb/servers/$id';
  static String smbConnect(String id) => '$baseUrl/smb/servers/$id/connect';
  static String get smbProbeConnect => '$baseUrl/smb/probe/connect';
  static String get smbProbeShares => '$baseUrl/smb/probe/shares';
  static String get smbProbeDirectories => '$baseUrl/smb/probe/directories';
  static String smbAlbums(String id) => '$baseUrl/smb/servers/$id/albums';
  static String smbItems(String id) => '$baseUrl/smb/servers/$id/items';
  static String smbDownload(String id) => '$baseUrl/smb/servers/$id/download';
  static String smbUpload(String id) => '$baseUrl/smb/servers/$id/upload';
  static String smbPreview(String id) => '$baseUrl/smb/servers/$id/preview';
  static String get transfers => '$baseUrl/transfers';
  static String transfer(String id) => '$baseUrl/transfers/$id';
  static String transferPause(String id) => '$baseUrl/transfers/$id/pause';
  static String transferResume(String id) => '$baseUrl/transfers/$id/resume';
}
