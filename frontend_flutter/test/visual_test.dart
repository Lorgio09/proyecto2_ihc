import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/autenticacion/login_view.dart';
import 'package:frontend_flutter/views/autenticacion/register_view.dart';
import 'package:frontend_flutter/views/home_view/home_view.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';

// Reference screenshots live in test/goldens. After an intentional visual
// change, regenerate them with: flutter test --update-goldens test/visual_test.dart

class _ServicioFalso extends PartidoService {
  @override
  Future<List<Partido>> listar() async => [
        Partido(
          id: 1,
          nombre: 'Fulbito del viernes',
          cantidadJugadores: 10,
          ubicacion: 'Cancha Central',
          fecha: null,
          estado: 'cupos abiertos',
          deporte: 'futbol',
        ),
      ];
}

/// Flutter's test environment draws every glyph as a solid block unless real
/// fonts are loaded, so the screenshots would show boxes instead of text.
/// The fonts come from the SDK itself, so nothing extra lives in the repo.
Future<void> _cargarFuentes() async {
  final raiz = Platform.environment['FLUTTER_ROOT'];
  if (raiz == null) return;
  final carpeta = '$raiz/bin/cache/artifacts/material_fonts';
  Future<void> cargar(String familia, List<String> archivos) async {
    final cargador = FontLoader(familia);
    for (final archivo in archivos) {
      final fuente = File('$carpeta/$archivo');
      if (fuente.existsSync()) {
        cargador.addFont(Future.value(ByteData.sublistView(fuente.readAsBytesSync())));
      }
    }
    await cargador.load();
  }

  await cargar('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  await cargar('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: pantalla,
    ),
  );
  // Images decode asynchronously; wait for them so the logo is in the shot.
  await tester.runAsync(() async {
    for (final elemento in find.byType(Image).evaluate()) {
      await precacheImage((elemento.widget as Image).image, elemento);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_cargarFuentes);

  testWidgets('el login se ve igual que la captura base', (tester) async {
    await _mostrar(tester, const LoginView());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/login.png'),
    );
  });

  testWidgets('el registro se ve igual que la captura base', (tester) async {
    await _mostrar(tester, const RegisterView());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/registro.png'),
    );
  });

  testWidgets('el inicio se ve igual que la captura base', (tester) async {
    await _mostrar(
      tester,
      HomeView(
        user: const Usuario(id: 1, nombre: 'Ana', email: 'ana@unisport.test'),
        authService: AuthService(),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/inicio.png'),
    );
  });

  testWidgets('Mis partidos se ve igual que la captura base', (tester) async {
    await _mostrar(tester, ListPartidoView(partidoService: _ServicioFalso()));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mis_partidos.png'),
    );
  });
}
