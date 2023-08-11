import 'package:flutter/material.dart';

class CustomSafeArea extends StatelessWidget {
  final Widget child;
  const CustomSafeArea({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          color: Theme.of(context).colorScheme.background,
          child: child,
        ),
      ),
    );
  }
}
