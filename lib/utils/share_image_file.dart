import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Prepara uma imagem gerada em memória para o compartilhamento nativo.
///
/// No iOS, o compartilhador do sistema é mais confiável quando recebe o
/// caminho de um arquivo PNG real, em vez de bytes mantidos apenas em memória.
class ShareImageFile {
  static Future<XFile> prepare(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final imageInMemory = XFile.fromData(
      bytes,
      name: fileName,
      mimeType: 'image/png',
    );

    // Na web não há diretório temporário nativo para o app. O compartilhamento
    // continua usando os bytes, comportamento já suportado pelo navegador.
    if (kIsWeb) return imageInMemory;

    final temporaryDirectory = await getTemporaryDirectory();
    final path = '${temporaryDirectory.path}/$fileName';

    await imageInMemory.saveTo(path);

    return XFile(path, mimeType: 'image/png');
  }
}
