import 'package:flutter/material.dart';
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

Future<void> _mostrar(WidgetTester tester, Widget pantalla) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle();
}

void main() {
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
