import 'package:flutter_test/flutter_test.dart';
import 'package:clubbar_cliente/models/evento_detalhe.dart';

void main() {
  test('preserva fotos e contatos ao resolver o endereço do banner', () {
    final atracao = AtracaoEventoDetalhe.fromJson({
      'atracao_id': 2,
      'nmatracao': 'Banda',
      'urlbanneratracao': '/foto1.jpg',
      'urlfoto2atracao': '/foto2.jpg',
      'urlfoto3atracao': '/foto3.jpg',
      'instagram': '@banda',
      'telefone_contato': '35999999999',
      'video_instagram': 'https://instagram.com/reel/abc',
      'video_youtube': 'https://youtu.be/abc',
    });
    final resultado = atracao.comBanner('https://api.example.com/foto1.jpg');
    expect(resultado.bannerUrl, 'https://api.example.com/foto1.jpg');
    expect(resultado.foto2, '/foto2.jpg');
    expect(resultado.foto3, '/foto3.jpg');
    expect(resultado.instagram, '@banda');
    expect(resultado.telefoneContato, '35999999999');
    expect(resultado.videoInstagram, 'https://instagram.com/reel/abc');
    expect(resultado.videoYoutube, 'https://youtu.be/abc');
  });
}
