import 'package:flutter/material.dart';

import '../data/preferencias.dart';
import '../data/quiniela_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'estadisticas_screen.dart';
import 'generador_screen.dart';
import 'resultados_screen.dart';

/// Contenedor con la barra inferior. Mantiene vivas las 4 pantallas para que
/// cambiar de pestana no pierda el scroll ni vuelva a pedir los datos.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repositorio,
    required this.preferencias,
  });

  final QuinielaRepository repositorio;
  final PreferenciasLoterias preferencias;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  void _irA(int indice) => setState(() => _indice = indice);

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      DashboardScreen(
        repositorio: widget.repositorio,
        preferencias: widget.preferencias,
        onGenerarJugada: () => _irA(2),
        onVerResultados: () => _irA(1),
      ),
      ResultadosScreen(
        repositorio: widget.repositorio,
        preferencias: widget.preferencias,
      ),
      GeneradorScreen(repositorio: widget.repositorio),
      EstadisticasScreen(
        repositorio: widget.repositorio,
        preferencias: widget.preferencias,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(
        index: _indice,
        children: [
          // El IndexedStack construye las cuatro pantallas y pinta una sola,
          // pero los tickers de las ocultas siguen corriendo: sin el TickerMode,
          // el ticker de ultimo minuto y el punto de "en vivo" mantienen a la
          // app pidiendo frames a 60fps mientras se mira otra pestana.
          for (var i = 0; i < pantallas.length; i++)
            TickerMode(enabled: i == _indice, child: pantallas[i]),
        ],
      ),
      bottomNavigationBar: _BarraInferior(indice: _indice, onSeleccion: _irA),
    );
  }
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({required this.indice, required this.onSeleccion});

  final int indice;
  final ValueChanged<int> onSeleccion;

  static const _items = [
    (icono: Icons.dashboard, etiqueta: 'Inicio'),
    (icono: Icons.history, etiqueta: 'Resultados'),
    (icono: Icons.casino, etiqueta: 'Generador'),
    (icono: Icons.analytics, etiqueta: 'Stats'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
            left: AppSpacing.xs,
            right: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _items.length; i++)
                _ItemNav(
                  icono: _items[i].icono,
                  etiqueta: _items[i].etiqueta,
                  activo: i == indice,
                  onTap: () => onSeleccion(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemNav extends StatelessWidget {
  const _ItemNav({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.base,
            horizontal: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: activo
                ? AppColors.onSecondaryContainer
                : Colors.transparent,
            borderRadius: AppRadius.full,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icono,
                size: 24,
                color: activo
                    ? AppColors.secondaryFixed
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelCaps.copyWith(
                  color: activo
                      ? AppColors.secondaryFixed
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
