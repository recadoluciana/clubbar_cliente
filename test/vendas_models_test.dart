import 'package:clubbar_cliente/models/carrinho_item.dart';
import 'package:clubbar_cliente/models/carteira_item.dart';
import 'package:clubbar_cliente/models/produto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Produto', () {
    test('interpreta promoção e cortesia mesmo com números como texto', () {
      final produto = Produto.fromJson({
        'produto_id': '12',
        'organizacao_id': '3',
        'loja_id': '9',
        'categoria_id': '4',
        'nmproduto': 'Água',
        'vrprecoprod': '5,25',
        'vrprecofinal': '4.20',
        'tipodesconto': 'PERCENTUAL',
        'vrdesconto': '20',
        'descontoativo': 'true',
        'cortesia_disponivel': 1,
        'qtcortesiasrestantes': '2',
      });

      expect(produto.produtoId, 12);
      expect(produto.vrprecoprod, 5.25);
      expect(produto.vrprecofinal, 4.20);
      expect(produto.descontoativo, isTrue);
      expect(produto.cortesiaDisponivel, isTrue);
      expect(produto.cortesiasRestantes, 2);
    });

    test('monta caminho de foto relativo sem perder a barra', () {
      expect(
        Produto.buildUrl('uploads/agua.png'),
        '${Produto.baseUrl}/uploads/agua.png',
      );
    });
  });

  test('carrinho preserva dados de promoção por pacote', () {
    final item = ItemCarrinho.fromJson({
      'itcarrinho_id': 10,
      'produto_id': 12,
      'cardapioitem_id': 4,
      'campanha_id': 8,
      'tipo_campanha': 'PACOTE',
      'qtitenspacote': 3,
      'vrpacote': '12.00',
      'nmproduto': 'Água',
      'qt': 3,
      'vrprecoprod': '5.25',
      'vrprecofinal': '4.00',
    });

    expect(item.campanhaId, 8);
    expect(item.tipoCampanha, 'PACOTE');
    expect(item.quantidadePacote, 3);
    expect(item.valorPacote, 12);
    expect(item.precoOriginal, 5.25);
    expect(item.precoFinal, 4);
  });

  test('carteira conserva item disponível para retirada', () {
    final item = CarteiraItem.fromJson({
      'itvenda_id': '41',
      'loja_id': '9',
      'nmproduto': 'Cortesia Água',
      'qtitvenda': '1',
      'vrunititvenda': '0.00',
      'nmloja': 'Remelexo Brasil',
    });

    expect(item.id, 41);
    expect(item.quantidade, 1);
    expect(item.valorUnitario, 0);
    expect(item.status, 'Disponível');
    expect(item.nomeLoja, 'Remelexo Brasil');
  });
}
