import 'package:flutter/material.dart';
import 'package:worknet/core/widgets/error_notice.dart';

class Workspace extends StatelessWidget {
  const Workspace({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.loading = false,
    this.error,
    this.onRetry,
    this.scrollController,
  });
  final String title;
  final List<Widget> children, actions;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final ScrollController? scrollController;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'WORKNET',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 8, children: actions),
                const SizedBox(height: 24),
                if (loading) const LinearProgressIndicator(),
                if (error != null) ...[
                  ErrorNotice(error),
                  if (onRetry != null)
                    OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Reintentar'),
                    ),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 20),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}
