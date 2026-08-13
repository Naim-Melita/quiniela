import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Barra superior comun a todas las pantallas: avatar, marca y notificaciones.
class QuinielaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const QuinielaAppBar({super.key, this.titulo = 'Quiniela', this.onBuscar});

  final String titulo;

  /// Abre la busqueda de un numero. Si es null no se muestra la lupa.
  final VoidCallback? onBuscar;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDim,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.containerMargin,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHigh,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Expanded en vez de Spacer: con pantallas angostas el titulo se
              // corta con puntos suspensivos en lugar de desbordar la Row.
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headlineMd.copyWith(
                    color: AppColors.primaryFixedDim,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onBuscar != null)
                IconButton(
                  onPressed: onBuscar,
                  icon: const Icon(Icons.search),
                  color: AppColors.primaryFixedDim,
                  tooltip: 'Buscar un numero',
                ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
                color: AppColors.primaryFixedDim,
                tooltip: 'Notificaciones',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titulo de seccion (el "headline-lg-mobile" del diseno).
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            texto,
            style: AppText.headlineLgMobile.copyWith(color: AppColors.primary),
          ),
        ),
        ?accion,
      ],
    );
  }
}

/// Tarjeta base: fondo `surface-container`, radio 12 y borde tenue.
class TarjetaSuperficie extends StatelessWidget {
  const TarjetaSuperficie({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.surfaceContainer,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.allXl,
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}
