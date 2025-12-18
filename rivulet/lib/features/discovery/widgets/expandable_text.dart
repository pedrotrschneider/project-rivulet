import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final TextStyle? linkStyle;

  const ExpandableText(
    this.text, {
    super.key,
    this.maxLines = 3,
    this.style,
    this.linkStyle,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Create a TextSpan with the text and style
        final span = TextSpan(text: widget.text, style: widget.style);

        // Use TextPainter to determine if the text exceeds maxLines
        final tp = TextPainter(
          text: span,
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        );
        tp.layout(maxWidth: constraints.maxWidth);

        if (!tp.didExceedMaxLines) {
          // Text fits within maxLines, so just show the text directly
          return Text(widget.text, style: widget.style);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedCrossFade(
              firstChild: Text(
                widget.text,
                style: widget.style,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
              ),
              secondChild: Text(widget.text, style: widget.style),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  _expanded ? 'Show less' : 'Show more',
                  style:
                      widget.linkStyle ??
                      Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
