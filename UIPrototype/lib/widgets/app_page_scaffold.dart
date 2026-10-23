import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.children,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.fromLTRB(22, 18, 22, 112),
    this.maxWidth = 430,
    this.floatingActionButton,
    this.scrollController,
  });

  final List<Widget> children;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final Widget? floatingActionButton;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar == null
          ? null
          : CenteredAppShell(
              maxWidth: maxWidth,
              child: bottomNavigationBar!,
            ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppGradients.page,
          ),
        ),
        child: CenteredAppShell(
          maxWidth: maxWidth,
          child: SafeArea(
            bottom: false,
            child: ListView(
              controller: scrollController,
              padding: padding,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class CenteredAppShell extends StatelessWidget {
  const CenteredAppShell({
    super.key,
    required this.child,
    this.maxWidth = 430,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
