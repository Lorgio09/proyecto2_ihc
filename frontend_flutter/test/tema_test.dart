import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/theme/app_theme.dart';
import 'package:frontend_flutter/theme/tokens.dart';

// El tema debe pintar los diálogos y los botones deshabilitados con los tokens
// del sistema de diseño, igual que los componentes de Figma, nunca con los
// valores por defecto de Material.
void main() {
  Future<BuildContext> montar(WidgetTester tester, Widget hijo) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPrincipal,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              contexto = context;
              return hijo;
            },
          ),
        ),
      ),
    );
    return contexto;
  }

  testWidgets('dialog uses superficie and the texto/titulo style', (
    tester,
  ) async {
    final contexto = await montar(tester, const SizedBox());
    showDialog<void>(
      context: contexto,
      builder: (_) =>
          const AlertDialog(title: Text('Título'), content: Text('Contenido')),
    );
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, UniColores.superficie);
    expect(material.surfaceTintColor, Colors.transparent);

    final titulo = tester.widget<RichText>(
      find.descendant(of: find.text('Título'), matching: find.byType(RichText)),
    );
    expect(titulo.text.style?.fontSize, UniTexto.titulo.fontSize);
    expect(titulo.text.style?.fontWeight, UniTexto.titulo.fontWeight);
    expect(titulo.text.style?.color, UniColores.texto);
  });

  testWidgets('disabled FilledButton uses deshabilitado and texto-secundario', (
    tester,
  ) async {
    await montar(
      tester,
      const FilledButton(onPressed: null, child: Text('Buscar partidos')),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, UniColores.deshabilitado);
    expect(material.textStyle?.color, UniColores.textoSecundario);
  });

  testWidgets('enabled FilledButton keeps primario with sobre-color', (
    tester,
  ) async {
    await montar(
      tester,
      FilledButton(onPressed: () {}, child: const Text('Buscar partidos')),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, UniColores.primario);
    expect(material.textStyle?.color, UniColores.sobreColor);
  });
}
