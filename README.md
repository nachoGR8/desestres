# 🫧 Desestres

App anti-estrés hecha con Flutter como regalo personal. Todo funciona en local — sin backend, sin login, sin base de datos remota. Incluye mini-juegos de relajación, seguimiento de ánimo, diario de gratitud, jardín virtual, sistema de logros y cartas secretas desbloqueables.

## ✨ Funcionalidades

### 🎮 Mini-juegos
| Juego | Descripción |
|---|---|
| **Respiración** | Respiración guiada con 3 patrones (4-4-6, 4-7-8, box breathing) |
| **Burbujas** | Explota burbujas flotantes con efectos de partículas |
| **Granitos** | Mantén pulsado para reventar granitos con efectos de pus |
| **Dibujo zen** | Trazos libres que se desvanecen suavemente |
| **Jarro de preocupaciones** | Escribe lo que te preocupa y disuélvelo |
| **Mandala** | Colorea mandalas simétricos (6 patrones) |

### 📊 Seguimiento
- **Ánimo diario** — selector de 5 niveles con nota opcional, calendario visual y gráfica de 30 días
- **Racha de uso** — días consecutivos con actividad
- **Resumen semanal** — estadísticas de la semana con mensaje motivacional
- **Estadísticas** — sesiones de respiración, burbujas explotadas, minutos totales...

### 🌱 Jardín virtual
Planta que crece con el uso diario de la app — 6 etapas de crecimiento desde semilla hasta árbol. Se riega automáticamente al usar la app o manualmente una vez al día.

### 🏆 Logros y cartas secretas
20+ logros desbloqueables con progreso visual. Cada logro desbloquea una carta secreta personalizada.

### 🆘 Botón SOS
Acceso rápido a respiración de emergencia 4-4-6 para momentos de ansiedad.

### 📝 Diario de gratitud
3 entradas diarias para reflexionar — con historial de los últimos 7 días.

## 🛠 Stack técnico

| | |
|---|---|
| **Framework** | Flutter 3.41.6 (stable) |
| **Lenguaje** | Dart ^3.11.4 |
| **Persistencia** | Hive (NoSQL local) + SharedPreferences |
| **Sonido** | audioplayers — WAV sintetizado en memoria |
| **Gráficas** | fl_chart |
| **Tipografía** | Nunito (Google Fonts) |
| **Notificaciones** | flutter_local_notifications + timezone |
| **State management** | setState |
| **Plataformas** | Android, iOS |

## 📁 Estructura

```
lib/
├── main.dart                  # Entry point
├── app.dart                   # MaterialApp + tema
├── theme/                     # Paleta de colores light/dark
├── data/                      # Frases y cartas
├── models/                    # MoodEntry, BreathingSession, Achievement
├── services/                  # Storage, Theme, Sound, Notifications
├── screens/                   # Pantallas principales
│   └── games/                 # Mini-juegos
└── widgets/                   # Componentes reutilizables
```

## 🚀 Ejecutar

```bash
flutter pub get
flutter run
```

## 📱 Tema

Soporte completo para tema claro y oscuro. Paleta basada en azules con acentos mint, rosa y lila. Material 3 con bordes redondeados (16–24px).
