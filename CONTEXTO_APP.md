# Desestres — Contexto Completo de la App

## Descripción General
App anti-estrés hecha con **Flutter** como regalo para la novia de Nacho. Todo funciona en local (sin backend, sin login, sin base de datos remota). Incluye frases de amor personalizadas, cartas secretas desbloqueables por logros, mini-juegos de relajación, diario de gratitud, seguimiento de ánimo, sistema de logros y estadísticas. Soporte para tema claro/oscuro.

## Datos del Proyecto
| Campo | Valor |
|---|---|
| **Nombre** | Desestres |
| **Bundle ID** | com.nacho.desestres |
| **Versión** | 1.0.0+1 |
| **Flutter** | 3.41.6 (stable) |
| **Dart SDK** | ^3.11.4 |
| **Plataformas** | Android, iOS (vía GitHub Actions + AltStore) |
| **Repo** | https://github.com/nachoGR8/desestres |
| **Estado** | `flutter analyze` → 0 issues |

## Paleta de Colores (azul — color favorito de la novia)

### Tema Claro
| Token | Hex | Uso |
|---|---|---|
| primary | #5B9CF6 | Color principal, botones, nav activo |
| primaryLight | #B3D4FF | Fondos suaves, selección |
| primaryDark | #3B7DD8 | Sombras, texto sobre fondo claro |
| secondary | #6EE7B7 | Mint — acentos positivos |
| accentPink | #FCA5A5 | Alertas suaves, ánimo bajo |
| accentLilac | #A78BFA | Respiración, gradientes |
| background | #F0F5FF | Fondo general |
| surface | #FFFFFF | Tarjetas, diálogos |
| textPrimary | #1E2A40 | Texto principal |
| textSecondary | #5A6B80 | Texto secundario |
| textHint | #9AACB8 | Placeholders |

### Tema Oscuro
| Token | Hex | Uso |
|---|---|---|
| background | #0F172A | Fondo general |
| surface | #1E293B | Tarjetas, diálogos |
| textPrimary | #E2E8F0 | Texto principal |
| textSecondary | #94A3B8 | Texto secundario |
| textHint | #64748B | Placeholders |

**Tipografía**: Nunito (via Google Fonts)
**Bordes**: 16–24px radius
**Material 3**: `useMaterial3: true`

## Dependencias (pubspec.yaml)
```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  hive: ^2.2.3                      # Base de datos local (NoSQL)
  hive_flutter: ^1.1.0              # Integración Hive + Flutter
  shared_preferences: ^2.3.0        # Persistencia tema + ajustes
  fl_chart: ^0.70.0                 # Gráficas (mood chart)
  google_fonts: ^6.2.1              # Tipografía Nunito
  flutter_animate: ^4.5.2           # Animaciones declarativas
  intl: ^0.19.0                     # Formateo de fechas en español
  audioplayers: ^6.1.0              # Efectos de sonido
  path_provider: ^2.1.0             # Acceso al sistema de archivos
  flutter_local_notifications: ^18.0.0  # Notificaciones locales
  timezone: ^0.10.0                 # Zonas horarias para notificaciones
```

## Arquitectura
- **State management**: `setState` (sin Provider/Bloc/Riverpod)
- **Persistencia**: Hive con TypeAdapters escritos a mano (sin build_runner)
- **Patrón de servicio**: 4 singletons (`StorageService`, `ThemeService`, `SoundService`, `NotificationService`)
- **Navegación**: Navigator 1.0 con push/pushReplacement + `WavePageRoute` custom
- **Estructura de carpetas**:

```
lib/
├── main.dart                          # Entry point (init de todos los servicios)
├── app.dart                           # MaterialApp config + ThemeService listener
├── theme/
│   └── app_theme.dart                 # Colores light/dark, tipografía, ThemeData
├── data/
│   ├── love_phrases.dart              # 47 frases de amor de Nacho 🤍
│   └── cartas.dart                    # 22 cartas secretas (map achievementId → texto)
├── models/
│   ├── mood_entry.dart                # Modelo ánimo (HiveType 0)
│   ├── mood_entry.g.dart              # Adapter generado a mano
│   ├── breathing_session.dart         # Modelo sesión respiración (HiveType 1)
│   ├── breathing_session.g.dart       # Adapter generado a mano
│   └── achievement.dart               # Modelo logro + 20+ definiciones con check/progress
├── services/
│   ├── storage_service.dart           # Singleton: Hive CRUD + rachas + contadores + gratitud
│   ├── theme_service.dart             # ValueNotifier<ThemeMode> + SharedPreferences
│   ├── sound_service.dart             # Síntesis WAV + pool de AudioPlayers
│   └── notification_service.dart      # Notificaciones locales diarias con timezone
├── screens/
│   ├── welcome_screen.dart            # Splash con frase de amor, auto → Home
│   ├── home_screen.dart               # BottomNav: Jugar | Ánimo | Progreso
│   ├── games_hub_screen.dart          # Selector de juegos + contador días juntos + SOS
│   ├── mood_screen.dart               # Selector 1-5 + nota + calendario + historial 7d
│   ├── stats_screen.dart              # Racha + stats respiración + chart 30d + logros
│   ├── sos_calm_screen.dart           # Respiración guiada 4-4-6 de emergencia
│   ├── gratitude_screen.dart          # Diario de gratitud (3 campos diarios)
│   ├── cartas_screen.dart             # Cartas secretas desbloqueables por logros
│   └── games/
│       ├── breathing_game.dart        # Juego de respiración (3 patrones)
│       ├── bubble_pop_game.dart       # Explotar burbujas flotantes
│       ├── zen_draw_game.dart         # Dibujo zen con trazos que se desvanecen
│       ├── worry_jar_game.dart        # Jarro de preocupaciones (escribir + deslizar)
│       └── mandala_game.dart          # Mandalas simétricos para colorear (6 patrones)
└── widgets/
    ├── breathing_circle.dart          # Círculo animado + BreathingPattern
    ├── mood_selector.dart             # 5 emojis seleccionables
    ├── mood_chart.dart                # LineChart 30 días con fl_chart
    ├── mood_calendar.dart             # Calendario con ánimo por color
    ├── streak_card.dart               # Tarjeta de racha 🔥
    ├── achievements_grid.dart         # Grid de logros (bloqueados/desbloqueados)
    └── page_transitions.dart          # WavePageRoute — transición custom
```

## Inicialización (main.dart)
```
1. WidgetsFlutterBinding.ensureInitialized()
2. SystemChrome.setSystemUIOverlayStyle() — barra de estado transparente
3. initializeDateFormatting('es') — locale español
4. StorageService().init() — Hive + almacenamiento local
5. ThemeService().init() — cargar preferencia de tema
6. SoundService().init() — generar y cachear WAVs
7. NotificationService().init() — programar recordatorio diario
8. runApp(DesestresApp) → WelcomeScreen
```

## Flujo de la App
```
1. SPLASH (welcome_screen)
   → Muestra frase aleatoria de Nacho con 🤍
   → Animación fade-in + corazón animado
   → Auto-navega a Home (o tap)

2. HOME (home_screen) — 3 tabs
   ├── TAB 1: JUGAR (games_hub_screen)
   │   ├── Contador de días juntos
   │   ├── Botón SOS → sos_calm_screen (respiración 4-4-6 de emergencia)
   │   ├── Respiración → breathing_game (3 patrones: 4-4-6, 4-7-8, 4-4-4-4)
   │   ├── Burbujas → bubble_pop_game (tap para explotar)
   │   ├── Dibuja zen → zen_draw_game (trazos se desvanecen)
   │   ├── Jarro → worry_jar_game (escribir preocupaciones, deslizar para disolver)
   │   ├── Mandala → mandala_game (6 patrones simétricos para colorear)
   │   ├── Gratitud → gratitude_screen (diario de 3 entradas diarias)
   │   └── Cartas → cartas_screen (22 cartas desbloqueables por logros)
   │
   ├── TAB 2: ÁNIMO (mood_screen)
   │   → Selector 5 niveles (😫😕😐🙂😄)
   │   → Nota opcional (140 chars)
   │   → 1 entrada por día (actualiza si ya existe)
   │   → Calendario visual con colores por ánimo
   │   → Historial últimos 7 días
   │
   └── TAB 3: PROGRESO (stats_screen)
       → Racha actual / mejor racha (🔥)
       → Sesiones de respiración (cantidad + minutos)
       → Gráfica de ánimo últimos 30 días
       → Grid de logros (20+ achievements)
```

## Sistema de Logros (achievement.dart)
20+ logros con progreso 0.0–1.0 y funciones de verificación automática:

| Categoría | Logros |
|---|---|
| **Ánimo** | first_mood, mood_14, mood_30 |
| **Rachas** | streak_3, streak_7, streak_30 |
| **Respiración** | first_breath, breath_20, breath_50, breath_60min, breath_120min |
| **Burbujas** | bubbles_100, bubbles_500 |
| **Preocupaciones** | worries_20, worries_50 |
| **Zen** | zen_10 |
| **Mandala** | mandala_1, mandala_5, mandala_10 |
| **Misc** | explorer, gratitude_7 |

Cada logro desbloquea una carta secreta de Nacho en `cartas_screen`.

## Cartas Secretas (cartas.dart)
22 cartas de amor escritas por Nacho, vinculadas a logros. Ejemplos:
- `first_mood`: "Hice esta app pensando solo en ti..."
- `streak_30`: "Un mes entero sin fallarte..."
- `breath_120min`: "Dos horas en total dedicadas a tu bienestar..."

## Servicios

### StorageService (154 líneas)
Singleton central de persistencia vía Hive:
- CRUD de ánimo (`saveMood`, `getTodayMood`, `getMoods`)
- Sesiones de respiración (`saveSession`, `totalSessions`, `totalSecondsBreathing`)
- Rachas (`recordActivity`, `currentStreak`, `bestStreak`)
- Contadores de juegos (`incrementCounter` — burbujas, preocupaciones, zen, mandalas, etc.)
- Gratitud (`saveGratitude`, `getGratitude`, `getPastGratitude` — últimos 7 días)
- Cartas (`markCartaRead`, `cartasRead`)

### ThemeService (19 líneas)
`ValueNotifier<ThemeMode>` — toggle light/dark persistido en SharedPreferences.

### SoundService (288 líneas)
Sintetiza WAVs en memoria (pop, bell, click, whoosh, softTone, chime, breathIn, breathOut). Pool de 4 `AudioPlayer` para baja latencia. Toggle global on/off. Contexto de audio configurado para iOS (mixWithOthers) y Android (game usage).

### NotificationService (119 líneas)
Notificaciones locales con `flutter_local_notifications` + `timezone`. Recordatorio diario de ánimo. Soporte Android + iOS con manejo de permisos. Toggle global on/off.

## Almacenamiento Local (Hive)
| Box | Tipo | Contenido |
|---|---|---|
| `moods` | `Box<MoodEntry>` | Entradas de ánimo (key = "YYYY-MM-DD") |
| `sessions` | `Box<BreathingSession>` | Sesiones de respiración |
| `streak` | `Box` (dynamic) | `currentStreak`, `bestStreak`, `lastDate` |

### Lógica de Rachas
- Se registra actividad al guardar ánimo o completar cualquier juego
- Si `lastDate == ayer` → incrementa racha
- Si `lastDate == hoy` → no hace nada
- Si `lastDate < ayer` → reset a 1
- `bestStreak` se actualiza si `currentStreak > bestStreak`

## CI/CD — GitHub Actions
**Archivo**: `.github/workflows/build-ios.yml`
- **Trigger**: push a `main` o manual (workflow_dispatch)
- **Job iOS**: macOS runner → `flutter build ios --release --no-codesign` → empaqueta .ipa → artifact `Desestres-IPA` (90 días)
- **Job Android**: Ubuntu runner → Java 17 → `flutter build apk --release` → artifact `Desestres-APK` (90 días)

## Deploy
- **Android**: Descargar APK de GitHub Actions → instalar directamente
- **iOS**: Descargar IPA de GitHub Actions → instalar con AltStore (renovar cada 7 días)

## Líneas de Código
| Categoría | Archivos | Líneas |
|---|---|---|
| Entry + Config | main, app, theme | 227 |
| Data | love_phrases, cartas | 113 |
| Models | mood_entry, breathing_session, achievement + .g.dart | 351 |
| Services | storage, theme, sound, notification | 580 |
| Screens | 8 pantallas + 5 juegos | 3,623 |
| Widgets | 7 widgets | 962 |
| **Total** | **34 archivos** | **~5,856** |
