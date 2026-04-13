import re

file_path = "e:/Moimoi-POS-Flutter/lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# TARGET 1: Fix Expanded crash in _buildCalendarAmountBadge
target1 = """    return Container(
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

replacement1 = """    return Container(
      constraints: const BoxConstraints(maxWidth: 38),
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
          Flexible(
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

# TARGET 2: Selection style for day number
target2 = """                Positioned(
                  top: 0,
                  left: 2,
                  child: Text(
                    '${day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                      color: isSelected
                          ? AppColors.blue600
                          : AppColors.slate800,
                    ),
                  ),
                ),"""

replacement2 = """                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: isSelected ? BoxDecoration(
                      color: AppColors.blue600,
                      shape: BoxShape.circle,
                    ) : null,
                    child: Text(
                      '${day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppColors.slate800,
                      ),
                    ),
                  ),
                ),"""

# TARGET 3: Remove "Lịch giao dịch" text and "Đang chọn"
target3 = """        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lịch giao dịch',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
            ),
            if (_selectedDate != null)
              Text(
                'Đang chọn: ${_selectedDate!.day}/${_selectedDate!.month}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blue600,
                ),
              ),
          ],
        ),
        SizedBox(height: 16),"""

replacement3 = """        // Row text removed per user request"""

if target1 in text:
    text = text.replace(target1, replacement1)
    print("TARGET 1 SUCCESS")
else:
    print("TARGET 1 NOT FOUND")

if target2 in text:
    text = text.replace(target2, replacement2)
    print("TARGET 2 SUCCESS")
else:
    text = text.replace(target2.replace("'", '"'), replacement2)
    print("TARGET 2 NOT FOUND (tried double quotes)")

if target3 in text:
    text = text.replace(target3, replacement3)
    print("TARGET 3 SUCCESS")
else:
    print("TARGET 3 NOT FOUND")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)
