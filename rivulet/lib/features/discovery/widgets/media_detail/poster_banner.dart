import 'dart:io';
import 'package:flutter/material.dart';

class PosterBanner extends StatelessWidget {
  final String? posterUrl;
  final bool offlineMode;
  final IconData placeholderIcon;

  const PosterBanner({
    super.key,
    required this.posterUrl,
    this.offlineMode = false,
    this.placeholderIcon = Icons.movie,
  });

  @override
  Widget build(BuildContext context) {
    String? url = posterUrl;
    if (!offlineMode && url != null && url.startsWith('/')) {
      url = 'https://image.tmdb.org/t/p/w780$url';
    }

    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: url != null
              ? (offlineMode
                    ? Image.file(
                        File(url),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: Icon(placeholderIcon, size: 50),
                        ),
                      )
                    : Image.network(url, fit: BoxFit.cover))
              : Container(
                  color: Colors.grey[900],
                  child: Icon(placeholderIcon, size: 50),
                ),
        ),
      ),
    );
  }
}
