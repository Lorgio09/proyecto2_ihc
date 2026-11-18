# Tokens en el código: del inventario al sistema (UniSport)

Continuación de la Clase 23 (`evidencias/clase-23.md`): allí se hizo el inventario y se contaron los colores fijos sin tocar el código; aquí se corrigen.

## Integrantes

- Diego Andrés Astete Paz (sistema de diseño en Figma)
- Lorgio Choque Severiche (inventario y tokens en el código)

**Resultado:** todos los colores, estilos de texto y radios de la app salen de un único archivo de tokens, `frontend_flutter/lib/theme/tokens.dart`, con los mismos nombres que las variables de Figma. Ninguna pantalla tiene colores fijos: `grep` de `Colors.`, `Color(0x` y `Color.fromRGBO` fuera de ese archivo devuelve **0 resultados** (había 19).

---

## 1. Inventario de inconsistencias (antes)

Revisamos todo `frontend_flutter/lib/` buscando valores escritos a mano en lugar de tomados del tema.

### Color

| # | Dónde | Qué había | Por qué es una inconsistencia |
|---|---|---|---|
| C1 | `widgets/mensaje.dart` | Avisos (snackbar) con fondo `Colors.deepOrangeAccent` y texto blanco | Fuera de la paleta y **2.6:1 de contraste**, por debajo de AA (4.5:1). |
| C2 | `views/partido_view/formulario_partido.dart` (2 lugares) | Errores en `Colors.red.shade700` | Tres rojos distintos para "error" en la app: `red.shade700`, `Colors.red` y el `error` del tema. |
| C3 | `views/partido_view/historial_partidos_view.dart` | Ícono de error en `Colors.red` | Mismo caso que C2. |
| C4 | `views/partido_view/historial_partidos_view.dart` | Ícono de lista vacía en `Colors.grey` | Gris genérico de Material, no el gris azulado de la paleta. |
| C5 | `views/partido_view/list_partidoview.dart` | Botón "Reabrir equipo" en `Colors.green.shade800` | Usa el color de **éxito** para una acción secundaria, y es un verde distinto al de la insignia "Cupos abiertos". |
| C6 | `views/partido_view/explorar_partidos_view.dart` | Aviso "Ya estás unido" en `Colors.green.shade800` | Otro verde distinto al de la insignia. |
| C7 | `widgets/input.dart` (2 lugares) | Campo de solo lectura en `Colors.grey.shade200` y su texto en `Color.fromARGB(255, 56, 56, 56)` | Grises sueltos fuera de la paleta. |
| C8 | `widgets/tarjeta_partido.dart` (insignia) | 4 colores `Color.fromRGBO(...)` escritos a mano | Valores sueltos sin nombre: no se pueden reutilizar ni relacionar con Figma. |
| C9 | `widgets/tarjeta_partido.dart` (barra de cupos) | Fondo `Color.fromRGBO(236, 231, 226, 1)` | Igual que C8. |
| C10 | `widgets/tarjeta_partido.dart`, `views/home_view/home_view.dart` | Fondo de íconos con `CoralAccesible.withValues(alpha: 0.10)` y `0.12` | El mismo "coral suave" con dos opacidades distintas. |
| C11 | `theme/app_theme.dart` | Fondo de pantalla y borde de tarjeta con `Color.fromRGBO(...)` | Valores sin nombre dentro del tema. |
| C12 | `login_view`, `register_view`, `olvide_contraseña`, `cambiar_contraseña`, `home_view` | `backgroundColor: white` fijo en el `Scaffold` | Estas 5 pantallas eran blancas y el resto usaba el fondo del tema (#FAF8F6): dos fondos distintos en la misma app. |
| C13 | `consts/color.dart` | Nombres `Jetblack`, `Blueslate`, `CoralgLow` (con errata), `CoralAccesible`, `white` | Nombres en inglés y en estilos mezclados, que describen el tono y no el uso. No coincidían con nada en Figma. |

### Tipografía, radios y textos

| # | Dónde | Qué había | Por qué es una inconsistencia |
|---|---|---|---|
| T1 | `formulario_partido.dart`, `tarjeta_partido.dart` (4 lugares) | `fontSize: 12` escrito a mano | El mismo estilo "detalle" repetido a mano en vez de un estilo de texto con nombre. |
| T2 | `theme/app_theme.dart` | Solo 3 estilos de texto definidos (titular, título, subtítulo) | El resto dependía de los valores por defecto de Material, sin nombre propio. |
| R1 | `boton_guardar.dart` | Botón "Ingresar" / "Registrarme" con radio 10 | El resto de los botones de la app son de píldora: dos formas de botón principal. |
| R2 | `tarjeta_partido.dart` | Insignia con radio 20, barra de cupos con radio 4, ícono con radio 12 | Radios sueltos sin escala. |
| X1 | `register_view.dart` | "Ya tienes Cuenta? Inicia Sesion" | Sin signo de apertura, mayúsculas sueltas y sin tilde; en el login el equivalente dice "¿No tienes cuenta?". |
| X2 | `login_view.dart` | Enlace "Registrate" sin tilde y sin margen táctil | En el registro, el enlace equivalente tiene 14 px de margen vertical. |

---

## 2. Tokens (`frontend_flutter/lib/theme/tokens.dart`)

Cada token tiene el mismo nombre en Figma y en el código: la variable `color/primario` de Figma es `UniColores.primario` en Flutter.

| Grupo | Figma | Código | Tokens |
|---|---|---|---|
| Color | `color/*` | `UniColores.*` | primario, primario-claro, primario-suave, texto, texto-secundario, sobre-color, superficie, fondo, borde, pista, exito, exito-suave, neutro, neutro-suave, error, aviso, deshabilitado (17) |
| Tipografía | `texto/*` | `UniTexto.*` | titular 28/36, titulo 22/28, subtitulo 16/24, cuerpo 16/24, cuerpo-chico 14/20, detalle 12/16, boton 14/20 |
| Espaciado | `espacio/*` | `UniEspacio.*` | xs 4, s 8, m 12, l 16, xl 24 |
| Radio | `radio/*` | `UniRadio.*` | campo 8, icono 12, tarjeta 16, pildora 999 |

El tema (`theme/app_theme.dart`, `button_theme.dart`, `input_theme.dart`) se construye solo con estos tokens. También quedaron en el tema los avisos, los indicadores de progreso y los separadores, así cada pantalla los hereda sin escribir colores.

## 3. Qué se corrigió

| Inventario | Corrección |
|---|---|
| C1 | Avisos con `color/aviso` (#2D3142) y texto `color/sobre-color`: **contraste 12.9:1** (AA). Se define una vez en `snackBarTheme`. |
| C2, C3 | Un solo rojo: `color/error`, también como `colorScheme.error` y en el estilo de error de los campos. |
| C4 | `color/texto-secundario`. |
| C5 | "Reabrir equipo" pasa al estilo **secundario** (contorno en `color/primario`): reabrir no es un éxito, es la acción inversa de "Completar". |
| C6 | `color/exito`, el mismo verde de la insignia. |
| C7 | Fondo `color/deshabilitado` y texto `color/texto`. Además, todos los campos tienen fondo `color/superficie`. |
| C8, C9 | `color/exito`, `color/exito-suave`, `color/neutro`, `color/neutro-suave` y `color/pista`. |
| C10 | Un solo token sólido: `color/primario-suave`. |
| C11 | `color/fondo` y `color/borde`. |
| C12 | Se quitó el fondo fijo: las 5 pantallas usan `color/fondo`, como el resto. |
| C13 | Se eliminó `consts/color.dart`; todos los usos pasan a `UniColores.*`. |
| T1, T2 | `UniTexto.detalle` y los 7 estilos cargados en el `TextTheme`. |
| R1, R2 | `radio/pildora` para botones, insignia y barra; `radio/icono` para íconos. |
| X1, X2 | "¿Ya tienes cuenta? Inicia sesión" y "Regístrate", con el mismo margen táctil en los dos enlaces. |
| Inventario de la Clase 23, diferencia 3 | El botón para guardar un partido decía «save»; ahora dice «Guardar» (`views/partido_view/formulario_partido.dart:295`). |

**Pantallas sin colores fijos:** todas. Las de referencia son **Inicio** (`views/home_view/home_view.dart`) y **Mis partidos** (`views/partido_view/list_partidoview.dart` + `widgets/tarjeta_partido.dart`).

Las capturas base de las pruebas visuales (`test/goldens/`) se actualizaron a propósito por el cambio de fondo (C12) y del botón (R1). Pasan los 50 tests de Flutter.

## 4. Tabla componente ↔ archivo

Los 10 componentes del sistema de diseño en Figma y dónde está cada uno en el código.

| # | Componente (Figma) | Variantes y estados | Archivo |
|---|---|---|---|
| 1 | Botón | Principal, Secundario, Peligro, Texto · normal, presionado, deshabilitado, cargando | `lib/theme/button_theme.dart`, `lib/widgets/boton_guardar.dart`, `lib/widgets/confirmacion.dart` |
| 2 | Campo de texto | vacío, con texto, foco, error, solo lectura | `lib/widgets/input.dart`, `lib/theme/input_theme.dart` |
| 3 | Tarjeta de partido | Organizo, Me uní, Explorar · cupos abiertos, equipo completo, con aviso, jugado | `lib/widgets/tarjeta_partido.dart` (`TarjetaPartido`) |
| 4 | Insignia de estado | abierta, cerrada | `lib/widgets/tarjeta_partido.dart` (`_InsigniaEstado`) |
| 5 | Barra de cupos | vacía, parcial, llena | `lib/widgets/tarjeta_partido.dart` (`_Cupos`) |
| 6 | Diálogo de confirmación | normal, peligro | `lib/widgets/confirmacion.dart` |
| 7 | Diálogo informativo | ayuda, bloqueo | `lib/widgets/ayuda.dart`, `lib/views/cuenta/mi_cuenta_view.dart` |
| 8 | Aviso (snackbar) | solo texto, con acción | `lib/widgets/mensaje.dart`, `snackBarTheme` en `lib/theme/app_theme.dart` |
| 9 | Estado vacío | sin resultados, error, cargando | `lib/widgets/tarjeta_partido.dart` (`EstadoVacio`) |
| 10 | Acceso del inicio | normal, presionado | `lib/views/home_view/home_view.dart` (`_Acceso`) |
| — | Logo | completo, compacto | `lib/widgets/marca.dart` (`MarcaUniSport`) |

## 5. Pendiente

- **Espaciado:** los tokens `UniEspacio.*` ya existen, pero los márgenes de las pantallas todavía usan números. Hay valores fuera de la escala (3, 6, 10, 14, 32, 40). Es el siguiente paso, antes del corte del miércoles.
- **Sombra del logo:** se calcula a partir de `color/primario` con transparencia (`marca.dart:38`). No es un color fijo, pero en Figma conviene definirla como estilo de efecto.
