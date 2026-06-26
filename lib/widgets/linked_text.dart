import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../screens/hashtag_screen.dart';
import '../screens/profile_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Renders text with tappable `@username` mentions and `#hashtag` tokens.
/// - Tapping a mention resolves the username and opens that profile.
/// - Tapping a hashtag opens the [HashtagScreen] listing for that tag.
///
/// Used for post captions and comments. Recognizers are disposed to avoid
/// leaks across rebuilds.
class LinkedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Optional non-interactive spans rendered before [text] (e.g. a reply
  /// "@name " prefix in comments).
  final List<InlineSpan> prefix;

  const LinkedText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow,
    this.prefix = const [],
  });

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  Future<void> _openMention(String username) async {
    final u = await FirestoreService.instance.getUserByUsername(username);
    if (u == null || !mounted) return;
    final myUid = AuthService.instance.currentUser?.uid;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(uid: u.uid, isMe: myUid == u.uid),
      ),
    );
  }

  void _openHashtag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HashtagScreen(tag: tag.toLowerCase())),
    );
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final base = widget.style ??
        const TextStyle(fontSize: 13.5, color: AppColors.textDark, height: 1.4);
    final link = widget.linkStyle ??
        base.copyWith(
            color: AppColors.primaryCoral, fontWeight: FontWeight.w600);

    final spans = <InlineSpan>[...widget.prefix];
    final re = RegExp(r'(@[A-Za-z0-9_\.]{2,30}|#[A-Za-z0-9_]{1,50})');
    var last = 0;
    for (final m in re.allMatches(widget.text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      }
      final token = m.group(0)!;
      final rec = TapGestureRecognizer()
        ..onTap = () {
          if (token.startsWith('@')) {
            _openMention(token.substring(1));
          } else {
            _openHashtag(token.substring(1));
          }
        };
      _recognizers.add(rec);
      spans.add(TextSpan(text: token, style: link, recognizer: rec));
      last = m.end;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ??
          (widget.maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip),
    );
  }
}
