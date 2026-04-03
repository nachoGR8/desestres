# Desestres — Contexto Completo de la App

## Descripción General
App anti-estrés hecha con **Flutter** como regalo para la novia de Nacho. Todo funciona en local (sin backend, sin login, sin base de datos remota). Incluye frases de amor personalizadas, mini-juegos de relajación, seguimiento de ánimo y estadísticas.

## Datos del Proyecto
| Campo | Valor |
|---|---|
| **Nombre** | Desestres |
| **Bundle ID** | com.nacho.desestres |
| **Versión** | 1.0.0+1 |
| **Flutter** | 3.41.6 (stable) |
| **Dart** | 3.11.4 |
| **Plataformas** | Android, iOS (vía GitHub Actions + AltStore) |
| **Repo** | https://github.com/nachoGR8/desestres |
| **Estado** | `flutter analyze` → 0 issues |

## Paleta de Colores (azul — color favorito de la novia)
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

**Tipografía**: Nunito (via Google Fonts)
**Bordes**: 16–24px radius

## Dependencias (pubspec.yaml)
```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  hive: ^2.2.3            # Base de datos local (NoSQL)
  hive_flutter: ^1.1.0    # Integración Hive + Flutter
  shared_preferences: ^2.3.0  # (disponible, no usado activamente)
  fl_chart: ^0.70.0       # Gráficas (mood chart)
  google_fonts: ^6.2.1    # Tipografía Nunito
  flutter_animate: ^4.5.2 # Animaciones declarativas
  intl: ^0.19.0           # Formateo de fechas en español
```

## Arquitectura
- **State management**: `setState` (sin Provider/Bloc/Riverpod)
- **Persistencia**: Hive con TypeAdapters escritos a mano (sin build_runner)
- **Patrón de servicio**: `StorageService` singleton
- **Navegación**: Navigator 1.0 con push/pushReplacement
- **Estructura de carpetas**:

```
lib/
├── main.dart                          # Entry point
├── app.dart                           # MaterialApp config
├── theme/
│   └── app_theme.dart                 # Colores, tipografía, ThemeData
├── data/
│   └── love_phrases.dart              # 18 frases de amor de Nacho 🤍
├── models/
│   ├── mood_entry.dart                # Modelo ánimo (HiveType 0)
│   ├── mood_entry.g.dart              # Adapter generado a mano
│   ├── breathing_session.dart         # Modelo sesión respiración (HiveType 1)
│   └── breathing_session.g.dart       # Adapter generado a mano
├── services/
│   └── storage_service.dart           # Singleton: Hive CRUD + rachas
├── screens/
│   ├── welcome_screen.dart            # Splash con frase de amor, 4s → Home
│   ├── home_screen.dart               # BottomNav: Jugar | Ánimo | Progreso
│   ├── games_hub_screen.dart          # Grid 2×2 de mini-juegos
│   ├── mood_screen.dart               # Selector 1-5 + nota + historial 7d
│   ├── stats_screen.dart              # Racha + stats respiración + chart 30d
│   ├── breathing_screen.dart          # ⚠️ HUÉRFANO — no importado por nadie
│   └── games/
│       ├── breathing_game.dart        # Juego de respiración (3 patrones)
│       ├── bubble_pop_game.dart       # Explotar burbujas flotantes
│       ├── zen_draw_game.dart         # Dibujo zen con trazos que se desvanecen
│       └── worry_jar_game.dart        # Jarro de preocupaciones (escribir + deslizar)
└── widgets/
    ├── breathing_circle.dart          # Círculo animado + BreathingPattern
    ├── mood_selector.dart             # 5 emojis seleccionables
    ├── mood_chart.dart                # LineChart 30 días con fl_chart
    └── streak_card.dart               # Tarjeta de racha 🔥
```

## Flujo de la App
```
1. SPLASH (welcome_screen)
   → Muestra frase aleatoria de Nacho con 🤍
   → Animación fade-in + slide
   → Auto-navega a Home en 4s (o tap)

2. HOME (home_screen) — 3 tabs
   ├── TAB 1: JUGAR (games_hub_screen)
   │   ├── Respiración → breathing_game (3 patrones: 4-4-6, 4-7-8, 4-4-4-4)
   │   ├── Burbujas → bubble_pop_game (tap para explotar, máx 15)
   │   ├── Dibuja zen → zen_draw_game (trazos se desvanecen en 6s)
   │   └── Jarro → worry_jar_game (escribir preocupaciones, deslizar para disolver)
   │
   ├── TAB 2: ÁNIMO (mood_screen)
   │   → Selector 5 niveles (😫😕😐🙂😄)
   │   → Nota opcional (140 chars)
   │   → 1 entrada por día (actualiza si ya existe)
   │   → Historial últimos 7 días
   │
   └── TAB 3: PROGRESO (stats_screen)
       → Racha actual / mejor racha (🔥)
       → Sesiones de respiración (cantidad + minutos)
       → Gráfica de ánimo últimos 30 días
```

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

## Archivo Huérfano
- `lib/screens/breathing_screen.dart` (256 líneas) — versión antigua del juego de respiración, reemplazada por `games/breathing_game.dart`. No lo importa ningún archivo. Se puede borrar.

## Líneas de Código
| Categoría | Archivos | Líneas |
|---|---|---|
| Entry + Config | main, app, theme | 140 |
| Data + Models | phrases, models, adapters | 190 |
| Services | storage_service | 116 |
| Screens | 7 pantallas activas | 1,262 |
| Widgets | 4 widgets | 579 |
| Huérfano | breathing_screen | 256 |
| **Total** | **23 archivos** | **~2,847** |
