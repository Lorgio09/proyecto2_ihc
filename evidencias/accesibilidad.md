# Accesibilidad: reporte de Lighthouse interpretado y corregido (UniSport)

**Herramienta:** Lighthouse 12.6.1, categoría Accesibilidad, perfil móvil, sobre la app web (pantalla de inicio de sesión, la primera que ve cualquier persona).

| Reporte | Puntaje | Pasan | Fallan | No aplicables |
|---|---|---|---|---|
| [Antes](accesibilidad/lighthouse-antes.html) (app publicada) | 100 | 17 | 0 | **46** |
| [Después](accesibilidad/lighthouse-despues.html) (con las correcciones) | 100 | 20 | 0 | 43 |

## 1. Interpretación: el 100 del primer reporte no significaba «accesible»

El primer reporte dio 100, pero **46 de las revisiones quedaron como «no aplicables»**: Lighthouse no encontró nada que evaluar. La razón es cómo funciona Flutter web: dibuja la app sobre un `<canvas>` y **no crea el árbol de accesibilidad hasta que alguien lo activa** con un botón oculto («Enable accessibility»). Al revisar la página publicada, lo único que exponía era ese botón:

```
role="button" aria-label="Enable accessibility"      ← 1 solo elemento
```

Un lector de pantalla que entraba a UniSport encontraba lo mismo: una página vacía. El puntaje perfecto venía de que no había nada que pudiera fallar.

## 2. Correcciones

| # | Problema encontrado | Corrección | Dónde |
|---|---|---|---|
| 1 | En web, la app no exponía botones, campos ni textos a los lectores de pantalla (solo «Enable accessibility»). | La semántica se activa al arrancar en web. La pantalla de inicio pasó de **1 a 15 elementos accesibles** (campos, botones, textos). | `frontend_flutter/lib/accesibilidad.dart`, llamado desde `lib/main.dart` |
| 2 | Con la semántica activa apareció un error que Lighthouse no marca: **los campos se anunciaban con el texto de ejemplo** («correo@ejemplo.com», «••••••••») y no con su nombre. La etiqueta visible («Email») está encima del campo, pero no estaba conectada a él. | El campo `Input` usa su etiqueta como nombre accesible; la etiqueta visible no se lee dos veces. Ahora se anuncia «Email» y «Contraseña», con el ejemplo como pista. El botón del ojito sigue siendo un botón aparte («Mostrar contraseña»). | `frontend_flutter/lib/widgets/input.dart` · prueba: `test/input_semantica_test.dart` |
| 3 | El botón deshabilitado ponía texto gris sobre gris: **2.0:1** (hallado en el inventario de la Clase 23). WCAG 1.4.3 exime a los componentes inactivos, pero casi no se leía. | Texto `color/texto-secundario` sobre `color/deshabilitado`: **5.6:1**. | `frontend_flutter/lib/theme/button_theme.dart` |
| 4 | La pestaña del navegador decía «Inicio» (y antes «frontend_flutter»). | Título «UniSport» e idioma de la página `es`. | `lib/main.dart`, `web/index.html` |

Con la semántica activa, Lighthouse ya puede evaluar **etiquetas de los campos (`label`), contraste (`color-contrast`) y tamaño de los objetivos táctiles (`target-size`)**, y las tres pasan. Lo que sigue «no aplicable» son reglas de HTML que una app Flutter no usa (tablas, listas `<ul>`, imágenes `<img>`, `<video>`, etc.).

Cómo se ve la diferencia en la página:

```
Antes:   1 elemento   → [botón] Enable accessibility
Después: 15 elementos → [campo de texto] Email · [campo de contraseña] Contraseña
                        [botón] Mostrar contraseña · [botón] Ingresar
                        [botón] ¿Olvidaste tu contraseña? · [botón] Regístrate
```

## 3. Contraste AA comprobado

Lighthouse solo puede medir el contraste de lo que ve en el HTML, y Flutter pinta los colores en el `<canvas>`. Por eso el contraste se comprobó **midiendo cada par de colores de la app** con la fórmula de WCAG 2.1. Todos los colores salen de los tokens (`lib/theme/tokens.dart`), así que esta tabla cubre todas las pantallas. El mínimo AA es **4.5:1** para texto normal.

| Uso | Colores | Contraste |
|---|---|---|
| Texto principal sobre el fondo | `#2D3142` / `#FAF8F6` | 12.2:1 |
| Texto principal sobre tarjetas | `#2D3142` / `#FFFFFF` | 12.9:1 |
| Texto secundario sobre tarjetas | `#4F5D75` / `#FFFFFF` | 6.7:1 |
| Texto secundario sobre el fondo | `#4F5D75` / `#FAF8F6` | 6.3:1 |
| Botón principal: blanco sobre coral | `#FFFFFF` / `#C04A18` | 5.0:1 |
| Enlaces coral sobre tarjetas | `#C04A18` / `#FFFFFF` | 5.0:1 |
| Insignia «Cupos abiertos» | `#166534` / `#DCF1E2` | 6.0:1 |
| Insignia «Equipo completo» | `#374151` / `#E8EAEE` | 8.6:1 |
| Errores sobre blanco | `#B3261E` / `#FFFFFF` | 6.5:1 |
| Avisos: blanco sobre fondo oscuro | `#FFFFFF` / `#2D3142` | 12.9:1 |
| Botón deshabilitado | `#4F5D75` / `#EEEBE8` | 5.6:1 |

Además, las pruebas automáticas revisan en cada push que las pantallas principales (inicio de sesión, registro, recuperar contraseña, Inicio, Mis partidos y Explorar) cumplan las guías de Flutter de **contraste de texto, tamaño mínimo de los objetivos táctiles (48 px en Android, 44 en iOS) y botones con nombre** (`test/accesibilidad_test.dart`).

## 4. Cómo repetir la medición

```bash
# App web compilada y servida en local (o la URL publicada)
cd frontend_flutter
flutter build web --release --dart-define=API_BASE_URL=https://unisport-api.onrender.com
cd build/web && python -m http.server 8080

# En otra terminal
npx lighthouse@12.6.1 http://127.0.0.1:8080/ --only-categories=accessibility --form-factor=mobile --output=html --output-path=lighthouse.html
```
