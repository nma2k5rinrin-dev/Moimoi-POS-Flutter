# -*- coding: utf-8 -*-
import sys

filepath = 'lib/features/dashboard/presentation/admin/admin_dashboard_page.dart'
content = open(filepath, encoding='utf-8').read()
lines = content.split('\n')

# Find the body section to replace: from line with "// ── Body: Expiry & Revenue ──" 
# to end of the footer section before closing ],),),);
# We need to replace lines 1750-1909 (the body + footer sections)

# Strategy: find the markers
body_start = None
body_end = None

for i, line in enumerate(lines):
    if '// ── Body: Expiry & Revenue ──' in line:
        body_start = i - 1  # include the SizedBox(height: 16) before it
    if body_start is not None and '// ── Footer: Last online & Action Buttons ──' in line:
        # Find the end of the footer section - look ahead for the closing brackets
        for j in range(i, min(i+100, len(lines))):
            stripped = lines[j].strip()
            if j > i + 5 and stripped == '],':
                # Check if 3 lines ahead is ),),);
                if (j+1 < len(lines) and lines[j+1].strip() == '),' and
                    j+2 < len(lines) and lines[j+2].strip() == '),' and
                    j+3 < len(lines) and lines[j+3].strip() == ');'):
                    body_end = j + 3  # include the );
                    break
        break

if body_start is None or body_end is None:
    print(f"Could not find markers. body_start={body_start}, body_end={body_end}")
    sys.exit(1)

print(f"Replacing lines {body_start+1} to {body_end+1}")

# New replacement: plan info + expiry + action buttons, NO DT:N/A, NO login status
new_body = """            SizedBox(height: 12),

            // ── Plan & Expiry Info ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isPremium ? Color(0xFFFFFBEB) : AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPremium ? Color(0xFFFDE68A) : AppColors.slate200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isPremium ? Icons.workspace_premium : Icons.inventory_2_outlined,
                    size: 16,
                    color: isPremium ? Color(0xFFD97706) : AppColors.slate400,
                  ),
                  SizedBox(width: 6),
                  Text(
                    isPremium ? 'Premium' : 'C\u01a1 b\u1ea3n',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPremium ? Color(0xFFD97706) : AppColors.slate500,
                    ),
                  ),
                  Spacer(),
                  Text(
                    info.daysUntilExpiry != null
                        ? 'H\u1ebft h\u1ea1n: ${_formatDate(DateTime.now().add(Duration(days: info.daysUntilExpiry!)))}'
                        : 'Kh\u00f4ng h\u1ebft h\u1ea1n',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (info.daysUntilExpiry != null && info.daysUntilExpiry! <= 7)
                          ? Color(0xFFEF4444)
                          : AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            if (hasPendingUpgrade) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.orange50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Text(
                      'Y\u00eau c\u1ea7u n\u00e2ng c\u1ea5p \u0111ang ch\u1edd duy\u1ec7t',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 12),

            // ── Action Buttons ──
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showPremiumPopup(context, storeName),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.emerald500),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Gia h\u1ea1n ngay',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StoreDetailPage(
                          storeId: storeId,
                          info: info,
                          store: store,
                          colorIndex: colorIndex,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.emerald500,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald500.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Chi ti\u1ebft',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );"""

# Now also need to add wave background for premium cards
# We need to wrap the Container child with a Stack that includes a wave painter
# Find the line with "child: Container(" inside _StoreCard build method
# Line 1584: child: Container(

# Let's also modify the card to use Stack with wave background for premium
# Find: "child: Container(\n        padding: EdgeInsets.all(cardPad),"
# Replace with Stack + Positioned wave + original Container

container_marker = "      child: Container(\n        padding: EdgeInsets.all(cardPad),\n        clipBehavior: Clip.hardEdge,"
wave_replacement = """      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(cardPad),
            clipBehavior: Clip.hardEdge,"""

# And close the Stack after our new body ends
# The card currently ends with:  ),  );  }
# We need to add the wave painter as a Positioned before closing the Stack

lines_new = lines[:body_start] + new_body.split('\n') + lines[body_end+1:]
content_new = '\n'.join(lines_new)

# Now add the wave for premium: wrap Container in Stack
content_new = content_new.replace(container_marker, wave_replacement, 1)

# Find the closing of the card: the "    );\n  }\n\n  void _showPremiumPopup"
# We need to insert the wave Positioned and close the Stack
old_card_end = "    );\n  }\n\n  void _showPremiumPopup"
new_card_end = """          if (isPremium)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _WavePainter(
                    color: Color(0xFFF59E0B).withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPremiumPopup"""
content_new = content_new.replace(old_card_end, new_card_end, 1)

# Now add the _WavePainter class at the end of the file (before the last closing })
# Find _badge helper and add _WavePainter after the _StoreCard class or at end
# Let's add it right before the _AddStoreCard class

add_store_marker = "class _AddStoreCard extends StatelessWidget {"
wave_class = """class _WavePainter extends CustomPainter {
  final Color color;
  _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.45,
      size.width * 0.5, size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.75,
      size.width, size.height * 0.55,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Second wave layer
    final path2 = Path();
    path2.moveTo(0, size.height * 0.75);
    path2.quadraticBezierTo(
      size.width * 0.3, size.height * 0.65,
      size.width * 0.6, size.height * 0.78,
    );
    path2.quadraticBezierTo(
      size.width * 0.85, size.height * 0.88,
      size.width, size.height * 0.7,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.color != color;
}

""" + add_store_marker

content_new = content_new.replace(add_store_marker, wave_class, 1)

open(filepath, 'w', encoding='utf-8').write(content_new)
print("Done! Patched _StoreCard successfully.")
