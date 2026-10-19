import 'package:flutter/material.dart';

import 'package:worknet/core/theme/worknet_theme.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.headline,
    required this.description,
    required this.child,
  });

  final String headline;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final horizontalPadding = wide ? 48.0 : 24.0;
            final form = Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: wide ? 48 : 30,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!wide) ...[const _Brand(), const SizedBox(height: 32)],
                  child,
                ],
              ),
            );
            return Scrollbar(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 32 : 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: WorkNetColors.line),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: wide
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: _BrandPanel(
                                        headline: headline,
                                        description: description,
                                      ),
                                    ),
                                    Expanded(flex: 6, child: form),
                                  ],
                                ),
                              )
                            : form,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : WorkNetColors.dark;
    return Row(
      children: [
        Icon(Icons.work_outline_rounded, color: color, size: 26),
        const SizedBox(width: 10),
        Text(
          'WorkNet',
          style: TextStyle(
            color: color,
            fontSize: 27,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.headline, required this.description});

  final String headline;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WorkNetColors.dark,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Brand(light: true),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: const TextStyle(
                      fontSize: 39,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: WorkNetColors.onBrandMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'Conecta tu talento con tu próximo paso.',
              style: TextStyle(color: WorkNetColors.onBrandMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
