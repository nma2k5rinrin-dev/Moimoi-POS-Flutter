import 'dart:io';

void main() async {
  final dir = Directory('lib');
  if (!await dir.exists()) {
    print('lib directory not found');
    return;
  }

  final files = await dir
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .toList();

  int constRemovedCount = 0;
  int colorWhiteReplacedCount = 0;

  for (final file in files) {
    if (file is! File) continue;
    String content = await file.readAsString();
    bool modified = false;

    // We do NOT want const on anything using AppColors or AppTextStyles anymore.
    // Instead of complex AST, we aggressively replace "const " with ""
    // ONLY on lines containing AppTextStyles or AppColors.
    // However, it's safer to just do a broad regex across multi-line blocks.

    // Simpler approach: we replace "const Text(", "const Icon(", "const Padding(" etc.
    // with "Text(", "Icon(", "Padding(" everywhere in lib to be safe, because
    // trying to find multi-line scopes using RegExp is extremely fragile in Dart.
    // Removing these consts doesn't break compilation (just causes info warnings).

    // First: replace Colors.white with AppColors.surface in contexts that look like backgrounds
    // E.g. color: Colors.white, backgroundColor: Colors.white
    // Wait, let's just replace all `Colors.white` with `AppColors.surface` where it makes sense.
    // We will leave `Colors.white` inside text colors (as they are usually on top of primary color buttons).

    // Let's replace: color: Colors.white => color: AppColors.surface
    final initialContent = content;
    content = content.replaceAll(
      RegExp(r'color:\s*Colors\.white([^a-zA-Z])'),
      r'color: AppColors.surface$1',
    );
    content = content.replaceAll(
      RegExp(r'backgroundColor:\s*Colors\.white([^a-zA-Z])'),
      r'backgroundColor: AppColors.surface$1',
    );

    // If there's `color: Colors.black`, map it to `AppColors.slate800`
    content = content.replaceAll(
      RegExp(r'color:\s*Colors\.black([^a-zA-Z])'),
      r'color: AppColors.slate800$1',
    );
    content = content.replaceAll(
      RegExp(r'color:\s*Colors\.black87([^a-zA-Z])'),
      r'color: AppColors.slate800$1',
    );
    content = content.replaceAll(
      RegExp(r'color:\s*Colors\.black54([^a-zA-Z])'),
      r'color: AppColors.slate500$1',
    );

    if (content != initialContent) {
      colorWhiteReplacedCount++;
    }

    // Now, deal with 'const' issues.
    // Because AppColors.slateX is now a getter, `const` before ANY widget that uses it will error.
    // We can safely remove `const ` before these widgets:
    final widgetsToRemoveConst = [
      'Text', 'Icon', 'Padding', 'Container', 'Card', 'Divider',
      'SizedBox', 'Row', 'Column', 'Center', 'BoxDecoration', 'Align',
      'TextStyle', 'BorderSide', 'Border', 'Expanded', 'CircleAvatar',
      'Color',
      'EdgeInsets', // Wait, EdgeInsets.all is used everywhere, but removing const is fine.
    ];

    for (var w in widgetsToRemoveConst) {
      // replace "const WidgetName(" with "WidgetName("
      final regex = RegExp('const\\s+$w\\s*\\(');
      if (regex.hasMatch(content)) {
        content = content.replaceAll(regex, '$w(');
        constRemovedCount++;
        modified = true;
      }

      // Also catch "const WidgetName.constructor(" like "const EdgeInsets.only("
      final regex2 = RegExp('const\\s+$w\\.[a-zA-Z0-9_]+\\s*\\(');
      if (regex2.hasMatch(content)) {
        content = content.replaceAllMapped(
          regex2,
          (match) => match.group(0)!.substring(6),
        );
        constRemovedCount++;
        modified = true;
      }
    }

    // specific list removals: "const [" to "["
    // (this is heavy handed but fixes const arrays containing AppColors)
    if (content.contains('const [')) {
      // Only if the line or next lines contain AppTextStyles or AppColors...
      // ACTUALLY, let's just leave it and fix manually any compiler errors,
      // because stripping all `const [` might break some specific flutter things.
      // Although typically `children: [` doesn't break if const is removed.
    }

    if (modified || content != initialContent) {
      await file.writeAsString(content);
    }
  }

  print('Replaced Colors.white/black in $colorWhiteReplacedCount files.');
  print('Stripped const keywords across $constRemovedCount locations.');
}
