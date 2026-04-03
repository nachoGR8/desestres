import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/storage_service.dart';

class WorryJarGame extends StatefulWidget {
  const WorryJarGame({super.key});

  @override
  State<WorryJarGame> createState() => _WorryJarGameState();
}

class _WorryJarGameState extends State<WorryJarGame> {
  final _textController = TextEditingController();
  final List<_Worry> _worries = [];
  int _dissolvedCount = 0;
  bool _hasUsed = false;

  void _addWorry() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _worries.add(_Worry(
        id: DateTime.now().microsecondsSinceEpoch,
        text: text,
      ));
      _hasUsed = true;
    });
    _textController.clear();
    FocusScope.of(context).unfocus();
  }

  void _dissolveWorry(_Worry worry) {
    HapticFeedback.mediumImpact();
    setState(() {
      _worries.removeWhere((w) => w.id == worry.id);
      _dissolvedCount++;
    });
    StorageService().incrementCounter('totalWorries');
  }

  Future<void> _exit() async {
    if (_hasUsed) {
      await StorageService().discoverGame('worry_jar');
      await StorageService().recordActivity();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _exit,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Theme.of(context).iconTheme.color,
                  ),
                  Expanded(
                    child: Text(
                      'Jarro de preocupaciones',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_dissolvedCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '✨ $_dissolvedCount',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Escribe lo que te preocupa y déjalo ir 🤍',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 20),

            // Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLength: 100,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addWorry(),
                      decoration: InputDecoration(
                        hintText: '¿Qué te preocupa?',
                        hintStyle: TextStyle(color: AppTheme.textHint),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addWorry,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Jar area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
                child: _worries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏺',
                                style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              _dissolvedCount > 0
                                  ? '¡Todo disuelto!\nTe has liberado de $_dissolvedCount preocupación${_dissolvedCount == 1 ? '' : 'es'}'
                                  : 'Tu jarro está vacío\nEscribe algo arriba',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _worries.length,
                        separatorBuilder: (context, i) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final worry = _worries[index];
                          return _WorryChip(
                            worry: worry,
                            onDissolve: () => _dissolveWorry(worry),
                          );
                        },
                      ),
              ),
            ),

            // Hint
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _worries.isNotEmpty
                    ? 'Arrastra a la izquierda para disolver'
                    : '',
                style: TextStyle(
                  color: AppTheme.textHint.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Worry {
  final int id;
  final String text;

  _Worry({
    required this.id,
    required this.text,
  });
}

class _WorryChip extends StatelessWidget {
  final _Worry worry;
  final VoidCallback onDissolve;

  const _WorryChip({
    required this.worry,
    required this.onDissolve,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip = Dismissible(
      key: ValueKey(worry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => onDissolve(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.secondary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          '✨ Soltar',
          style: TextStyle(
            color: Color(0xFF059669),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text('💭', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                worry.text,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.textHint.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );

    chip = chip.animate().fadeIn(duration: 300.ms).slideX(
          begin: 0.05,
          end: 0,
          duration: 300.ms,
        );

    return chip;
  }
}
