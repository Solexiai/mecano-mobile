// DRV-03 / DRV-10 (Bloc C, PR 7 — 2026-10-28).
//
// Un `StreamBuilder(stream: repo.watchX(id))` placé dans `build()` recrée le
// flux Firestore à CHAQUE reconstruction (setState, changement de langue,
// rotation) : nouvel abonnement, retour à l'état « en attente » (spinner
// plein écran) et lecture facturée. Ce widget crée le flux une seule fois et
// ne le remplace que si [id] change.
import 'package:flutter/material.dart';

class MemoizedStreamBuilder<T> extends StatefulWidget {
  const MemoizedStreamBuilder({
    super.key,
    required this.id,
    required this.create,
    required this.builder,
    this.initialData,
  });

  /// Identité du flux : un changement recrée le flux (ex. autre mission).
  final Object? id;
  final Stream<T> Function() create;
  final AsyncWidgetBuilder<T> builder;
  final T? initialData;

  @override
  State<MemoizedStreamBuilder<T>> createState() => _MemoizedStreamBuilderState<T>();
}

class _MemoizedStreamBuilderState<T> extends State<MemoizedStreamBuilder<T>> {
  late Stream<T> _stream = widget.create();

  @override
  void didUpdateWidget(covariant MemoizedStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _stream = widget.create();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: _stream,
    initialData: widget.initialData,
    builder: widget.builder,
  );
}
