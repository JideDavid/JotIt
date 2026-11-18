// Run separately with flutter run --profile -t tool/pin_benchmark.dart.
// This target never reads or changes saved notes, PINs or preferences.
import 'package:flutter/material.dart';
import 'package:jot_it/core/services/pin_hasher.dart';

void main() => runApp(const MaterialApp(home: PinBenchmark()));

class PinBenchmark extends StatefulWidget {
  const PinBenchmark({super.key});
  @override
  State<PinBenchmark> createState() => _PinBenchmarkState();
}

class _PinBenchmarkState extends State<PinBenchmark> {
  bool _busy = false;
  String _result = 'Ready to measure native verification on this device.';
  Future<void> _run() async {
    setState(() {
      _busy = true;
      _result = 'Measuring with synthetic test values…';
    });
    try {
      final hasher = PinHasher();
      final watch = Stopwatch()..start();
      final record = await hasher.hash('2468');
      final setup = watch.elapsedMilliseconds;
      final correct = <int>[], wrong = <int>[];
      for (var i = 0; i < 5; i++) {
        if (!mounted) return;
        for (final valid in [true, false]) {
          watch.reset();
          final accepted = await hasher.verify(valid ? '2468' : '8642', record);
          final elapsed = watch.elapsedMilliseconds;
          if (accepted != valid) {
            throw StateError('Compatibility check failed.');
          }
          (valid ? correct : wrong).add(elapsed);
        }
      }
      correct.sort();
      wrong.sort();
      if (mounted) {
        setState(
          () => _result =
              'Hash creation: $setup ms\n\n'
              'Correct PIN · median ${correct[2]} ms · slowest ${correct.last} ms\n'
              'Incorrect PIN · median ${wrong[2]} ms · slowest ${wrong.last} ms\n\n'
              'Five samples each. These measure derivation and comparison, not the full unlock screen.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _result =
              'Benchmark failed. No saved data was accessed or changed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PIN performance check')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text(
              'Uses synthetic test PINs. Your saved PINs and notes are never accessed.',
            ),
            const SizedBox(height: 24),
            Text(_result),
            const SizedBox(height: 24),
            if (_busy) const LinearProgressIndicator(),
            FilledButton(
              onPressed: _busy ? null : _run,
              child: const Text('Run benchmark'),
            ),
          ],
        ),
      ),
    ),
  );
}
