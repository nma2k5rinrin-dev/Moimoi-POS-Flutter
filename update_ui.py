import re

file_path = "e:/Moimoi-POS-Flutter/lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# TARGET 1: Highlight the transaction card
target1 = """    final card = Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate100),
      ),"""

replacement1 = """    final isMatchingDate = _selectedDate != null && 
                           _selectedDate!.year == t.date.year && 
                           _selectedDate!.month == t.date.month && 
                           _selectedDate!.day == t.date.day;

    final card = AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMatchingDate ? AppColors.blue50 : AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMatchingDate ? AppColors.blue400 : AppColors.slate100, width: isMatchingDate ? 1.5 : 1.0),
        boxShadow: isMatchingDate ? [
          BoxShadow(
            color: AppColors.blue200.withOpacity(0.5),
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ] : null,
      ),"""

# TARGET 2: Format Calendar Badges Without Abbreviations and scale them down
target2 = """    String _formatCompactAmount(double val) {
      if (val >= 1000000000)
        return '${(val / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}B';
      if (val >= 1000000)
        return '${(val / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
      if (val >= 1000)
        return '${(val / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
      return val.toStringAsFixed(0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: accent),
          const SizedBox(width: 2),
          Text(
            _formatCompactAmount(amount),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );"""

replacement2 = """    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 7, color: accent),
          const SizedBox(width: 2),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _formatAmount(amount),
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );"""

if target1 in text:
    text = text.replace(target1, replacement1)
    print("TARGET 1 SUCCESS")
else:
    print("TARGET 1 NOT FOUND")

if target2 in text:
    text = text.replace(target2, replacement2)
    print("TARGET 2 SUCCESS")
else:
    print("TARGET 2 NOT FOUND")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

print("DONE")
