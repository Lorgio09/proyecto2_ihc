import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/theme/app_theme.dart';
import 'package:frontend_flutter/views/autenticacion/login_view.dart';
import 'package:frontend_flutter/views/autenticacion/register_view.dart';
import 'package:frontend_flutter/views/home_view/home_view.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';

// Las capturas de referencia están en test/goldens. Tras un cambio visual
// intencional, regenéralas con: flutter test --update-goldens
// test/visual_test.dart

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

/// El entorno de pruebas de Flutter dibuja cada carácter como un bloque sólido
/// salvo que se carguen fuentes reales, así que las capturas mostrarían cajas
/// en vez de texto. Las fuentes vienen del propio SDK, así que no se guarda
/// nada extra en el repo.
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
      // El tema real de la app, para que las capturas muestren sus colores
      // reales.
      theme: temaPrincipal.copyWith(
        textTheme: temaPrincipal.textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: pantalla,
    ),
  );
  // Las imágenes se decodifican de forma asíncrona; se espera a que carguen
  // para que el logo salga en la captura.
  await tester.runAsync(() async {
    for (final elemento in find.byType(Image).evaluate()) {
      await precacheImage((elemento.widget as Image).image, elemento);
    }
  });
  await tester.pumpAndSettle();
}

/// Linux y Windows suavizan los bordes de los caracteres de forma un poco
/// distinta (cerca de 0.5 % a 1.5 % de los píxeles), así que la misma pantalla
/// nunca coincide byte a byte entre máquinas. Se tolera hasta un 2 %; un cambio
/// real en una pantalla (un botón nuevo, un bloque movido) difiere mucho más y
/// sigue fallando.
class _ComparadorConTolerancia extends LocalFileComparator {
  _ComparadorConTolerancia(super.testFile);

  static const tolerancia = 0.02;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final resultado = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (resultado.passed || resultado.diffPercent <= tolerancia) {
      resultado.dispose();
      return true;
    }
    final error = await generateFailureOutput(resultado, golden, basedir);
    resultado.dispose();
    throw FlutterError(error);
  }
}

void main() {
  setUpAll(() async {
    goldenFileComparator = _ComparadorConTolerancia(
      (goldenFileComparator as LocalFileComparator).basedir.resolve(
        'visual_test.dart',
      ),
    );
    await _cargarFuentes();
  });

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
