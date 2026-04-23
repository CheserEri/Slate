sealed class MediaSource {
  const MediaSource();

  factory MediaSource.local() = LocalSource;
  factory MediaSource.smb(String serverId) = SmbSource;

  Map<String, dynamic> toJson();
}

class LocalSource extends MediaSource {
  const LocalSource();

  @override
  Map<String, dynamic> toJson() => {'type': 'Local'};
}

class SmbSource extends MediaSource {
  final String serverId;
  const SmbSource(this.serverId);

  @override
  Map<String, dynamic> toJson() => {'type': 'Smb', 'server_id': serverId};
}

class MediaItem {
  final String id;
  final String name;
  final String path;
  final MediaSource source;
  final String mimeType;
  final int size;
  final int width;
  final int height;
  final DateTime modifiedAt;

  MediaItem({
    required this.id,
    required this.name,
    required this.path,
    required this.source,
    required this.mimeType,
    required this.size,
    required this.width,
    required this.height,
    required this.modifiedAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final sourceJson = json['source'] as Map<String, dynamic>;
    MediaSource source;
    if (sourceJson['type'] == 'Local') {
      source = MediaSource.local();
    } else {
      source = MediaSource.smb(sourceJson['server_id'] as String);
    }

    return MediaItem(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      source: source,
      mimeType: json['mime_type'] as String,
      size: json['size'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      modifiedAt: DateTime.parse(json['modified_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'source': source.toJson(),
      'mime_type': mimeType,
      'size': size,
      'width': width,
      'height': height,
      'modified_at': modifiedAt.toIso8601String(),
    };
  }
}

class Album {
  final String id;
  final String name;
  final MediaSource source;
  final String? coverPath;
  final int count;
  final String? parentPath;

  Album({
    required this.id,
    required this.name,
    required this.source,
    this.coverPath,
    required this.count,
    this.parentPath,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    final sourceJson = json['source'] as Map<String, dynamic>;
    MediaSource source;
    if (sourceJson['type'] == 'Local') {
      source = MediaSource.local();
    } else {
      source = MediaSource.smb(sourceJson['server_id'] as String);
    }

    return Album(
      id: json['id'] as String,
      name: json['name'] as String,
      source: source,
      coverPath: json['cover_path'] as String?,
      count: json['count'] as int,
      parentPath: json['parent_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'source': source.toJson(),
      'cover_path': coverPath,
      'count': count,
      'parent_path': parentPath,
    };
  }
}

class SmbConfig {
  final String id;
  final String name;
  final String host;
  final int port;
  final String share;
  final String username;
  final String? password;
  final DateTime createdAt;
  final DateTime updatedAt;

  SmbConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.share,
    required this.username,
    this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SmbConfig.fromJson(Map<String, dynamic> json) {
    return SmbConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      share: json['share'] as String,
      username: json['username'] as String,
      password: json['password'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson({bool includePassword = true}) {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'share': share,
      'username': username,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (includePassword) {
      map['password'] = password;
    }
    return map;
  }
}

enum TransferStatus { pending, running, paused, done, failed }

enum TransferType { download, upload }

class TransferTask {
  final String id;
  final String serverId;
  final TransferType transferType;
  final String remotePath;
  final String localPath;
  final int totalBytes;
  final int writtenBytes;
  final double progress;
  final TransferStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransferTask({
    required this.id,
    required this.serverId,
    required this.transferType,
    required this.remotePath,
    required this.localPath,
    required this.totalBytes,
    required this.writtenBytes,
    required this.progress,
    required this.status,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransferTask.fromJson(Map<String, dynamic> json) {
    return TransferTask(
      id: json['id'] as String,
      serverId: json['server_id'] as String,
      transferType: TransferType.values.firstWhere(
        (e) => e.name == json['transfer_type'],
        orElse: () => TransferType.download,
      ),
      remotePath: json['remote_path'] as String,
      localPath: json['local_path'] as String,
      totalBytes: json['total_bytes'] as int,
      writtenBytes: json['written_bytes'] as int,
      progress: (json['progress'] as num).toDouble(),
      status: TransferStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransferStatus.pending,
      ),
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
