import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_tracker/pokepc_local_repository.dart';
import 'package:pokedex_tracker/widgets.dart';

/// Comprueba que el widget Sprite resuelve los tokens `nid` de PokéPC al
/// archivo WEBP correcto (regular/shiny), incluidas formas y hembras.
void main() {
  Future<FileImage> renderedImage(WidgetTester tester, String token) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Sprite(token))));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    return image.image as FileImage;
  }

  String expected(String variant, String nid) =>
      PokepcLocalRepository.file('sprites/home3d/$variant/$nid.webp')
          .path
          .replaceAll('\\', '/');

  testWidgets('forma base y hembra cosmética', (tester) async {
    expect((await renderedImage(tester, 'pokepc:0003')).file.path.replaceAll('\\', '/'),
        expected('regular', '0003'));
    expect((await renderedImage(tester, 'pokepc:0003-f')).file.path.replaceAll('\\', '/'),
        expected('regular', '0003-f'));
  });

  testWidgets('mega, gigamax y hembra de forma', (tester) async {
    expect((await renderedImage(tester, 'pokepc:0003-mega')).file.path.replaceAll('\\', '/'),
        expected('regular', '0003-mega'));
    expect((await renderedImage(tester, 'pokepc:0025-gmax')).file.path.replaceAll('\\', '/'),
        expected('regular', '0025-gmax'));
    expect((await renderedImage(tester, 'pokepc:0678-f')).file.path.replaceAll('\\', '/'),
        expected('regular', '0678-f'));
  });

  testWidgets('variocolor de forma y hembra', (tester) async {
    expect((await renderedImage(tester, 'pokepc-shiny:0003-mega')).file.path.replaceAll('\\', '/'),
        expected('shiny', '0003-mega'));
    expect((await renderedImage(tester, 'pokepc-shiny:0003-f')).file.path.replaceAll('\\', '/'),
        expected('shiny', '0003-f'));
    expect((await renderedImage(tester, 'pokepc-shiny:0666-pokeball')).file.path.replaceAll('\\', '/'),
        expected('shiny', '0666-pokeball'));
  });
}