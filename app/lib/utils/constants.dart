class ApiConstants {
  static const String baseUrl = 'http://10.0.2.2:8080';

  static String get localAlbums => '$baseUrl/local/albums';
  static String localItems(String path) => '$baseUrl/local/albums/$path/items';
  static String get smbServers => '$baseUrl/smb/servers';
  static String smbServer(String id) => '$baseUrl/smb/servers/$id';
  static String smbConnect(String id) => '$baseUrl/smb/servers/$id/connect';
  static String smbAlbums(String id) => '$baseUrl/smb/servers/$id/albums';
  static String smbItems(String id) => '$baseUrl/smb/servers/$id/items';
  static String smbDownload(String id) => '$baseUrl/smb/servers/$id/download';
  static String smbUpload(String id) => '$baseUrl/smb/servers/$id/upload';
  static String get transfers => '$baseUrl/transfers';
  static String transfer(String id) => '$baseUrl/transfers/$id';
  static String transferPause(String id) => '$baseUrl/transfers/$id/pause';
  static String transferResume(String id) => '$baseUrl/transfers/$id/resume';
}
