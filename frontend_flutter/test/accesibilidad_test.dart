import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/partido.dart';
import 'package:frontend_flutter/models/usuario.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'package:frontend_flutter/services/partido.dart';
import 'package:frontend_flutter/views/autenticacion/login_view.dart';
import 'package:frontend_flutter/views/autenticacion/olvide_contraseña.dart';
import 'package:frontend_flutter/views/autenticacion/register_view.dart';
import 'package:frontend_flutter/views/home_view/home_view.dart';
import 'package:frontend_flutter/views/partido_view/explorar_partidos_view.dart';
import 'package:frontend_flutter/views/partido_view/list_partidoview.dart';

class _ServicioFalso extends PartidoService {
  @override
  Future<List<Partido>> listarExplorar({
    String? busqueda,
    String? deporte,
    String? zona,
    DateTime? desde,
    DateTime? hasta,
    bool soloConCupos = false,
  }) async => listar();

  @override
  Future<List<Partido>> listar() async => [
        Partido(
          id: 1,
          nombre: 'Partido de prueba',
          cantidadJugadores: 10,
          ubicacion: 'Cancha central',
          fecha: DateTime.now().add(const Duration(days: 3)),
          estado: 'cupos abiertos',
          deporte: 'futbol',
        ),
      ];
}

const _usuario = Usuario(id: 99, nombre: 'Ana', email: 'ana@unisport.test');

/// The same four checks on every screen: touch target size on both
/// platforms, a label on every tappable control, and text contrast.
Future<void> _cumpleLasGuias(WidgetTester tester, Widget pantalla) async {
  final semantica = tester.ensureSemantics();
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle();

  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  semantica.dispose();
}

void main() {
  testWidgets('Login cumple las guías de accesibilidad', (tester) async {
    await _cumpleLasGuias(tester, const LoginView());
  });

  testWidgets('Registro cumple las guías de accesibilidad', (tester) async {
    await _cumpleLasGuias(tester, const RegisterView());
  });

  testWidgets('Recuperar contraseña cumple las guías de accesibilidad',
      (tester) async {
    await _cumpleLasGuias(tester, const OlvideContrasenaView());
  });

  testWidgets('Mis partidos cumple las guías de accesibilidad',
      (tester) async {
    await _cumpleLasGuias(
      tester,
      ListPartidoView(partidoService: _ServicioFalso()),
    );
  });

  testWidgets('Explorar partidos cumple las guías de accesibilidad',
      (tester) async {
    await _cumpleLasGuias(
      tester,
      ExplorarPartidosView(
        usuario: _usuario,
        partidoService: _ServicioFalso(),
      ),
    );
  });

  testWidgets('Inicio cumple las guías de accesibilidad', (tester) async {
    await _cumpleLasGuias(
      tester,
      HomeView(user: _usuario, authService: AuthService()),
    );
  });
}
