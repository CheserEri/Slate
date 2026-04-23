import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'api/router.dart';
import 'services/local_photo_service.dart';
import 'services/smb_photo_service.dart';
import 'services/transfer_service.dart';

void main(List<String> args) async {
  final localRoot = _arg(args, '--local-root') ?? './photos';
  final port = int.tryParse(_arg(args, '--port') ?? '8080') ?? 8080;

  final localService = LocalPhotoService(localRoot);
  final smbService = SmbPhotoService();
  final transferService = TransferService(smbService);

  final api = ApiRouter(
    localService: localService,
    smbService: smbService,
    transferService: transferService,
  );

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(api.router);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('Slate backend running at http://${server.address.host}:$port');
  print('Local root: ${Directory(localRoot).absolute.path}');
}

String? _arg(List<String> args, String key) {
  final index = args.indexOf(key);
  if (index != -1 && index + 1 < args.length) {
    return args[index + 1];
  }
  return null;
}

Middleware _corsMiddleware() {
  return createMiddleware(
    requestHandler: (Request request) {
      if (request.method == 'OPTIONS') {
        return Response.ok(
          '',
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
          },
        );
      }
      return null;
    },
    responseHandler: (Response response) {
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
      });
    },
  );
}
