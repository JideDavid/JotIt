import 'package:flutter/material.dart';

class JotWordmark extends StatelessWidget {
  const JotWordmark({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/branding/jotit-symbol.png',
        width: 38,
        height: 38,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.high,
      ),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          'JotIt',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ),
    ],
  );
}

class QuietSectionLabel extends StatelessWidget {
  const QuietSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class QuietMessage extends StatelessWidget {
  const QuietMessage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: DefaultTextStyle(
      style: Theme.of(context).textTheme.bodySmall!,
      child: child,
    ),
  );
}
