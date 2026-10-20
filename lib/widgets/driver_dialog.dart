import 'package:flutter/material.dart';

/// Completes only after the route is removed. Dialog-owned controllers can then
/// be disposed without racing the reverse transition.
Future<T?> showDriverDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<T>(context: context, builder: builder);
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  return result;
}
