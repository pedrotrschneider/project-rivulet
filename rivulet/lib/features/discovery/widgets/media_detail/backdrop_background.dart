import 'dart:io';
import 'package:flutter/material.dart';

class BackdropBackground extends StatelessWidget {
  final String? backdropUrl;
  final bool offlineMode;

  const BackdropBackground({
    super.key,
    required this.backdropUrl,
    this.offlineMode = false,
  });

  @override
  Widget build(BuildContext context) {
    String? url = backdropUrl;
    if (!offlineMode && url != null && url.startsWith('/')) {
      url = 'https://image.tmdb.org/t/p/original$url';
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          Positioned.fill(
            child: offlineMode
                ? Image.file(
                    File(url),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor.withAlpha(150),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
                stops: const [0.0, 0.8],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
