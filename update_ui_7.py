import re

file_path = "e:/Moimoi-POS-Flutter/lib/features/cashflow/presentation/cashflow_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# REMOVE ICON IN CALENDAR BADGE
target1 = r"""        children: \[
          Icon\(icon,\s*size:\s*7,\s*color:\s*accent\),
          const SizedBox\(width: 2\),
          Flexible\("""

replacement1 = """        children: [
          Flexible("""

# REMOVE CIRCLE SELECTION IN CALENDAR CELL
target2 = r"""                Positioned\(
                  top: 0,
                  left: 0,
                  child: Container\(
                    width: 22,
                    height: 22,
                    alignment: Alignment\.center,
                    decoration: isSelected \? BoxDecoration\(
                      color: AppColors\.blue600,
                      shape: BoxShape\.circle,
                    \) : null,
                    child: Text\("""

replacement2 = """                Positioned(
                  top: 0,
                  left: 2,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    child: Text("""

new_text, count1 = re.subn(target1, replacement1, text)
new_text, count2 = re.subn(target2, replacement2, new_text)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_text)

print(f"COUNT1: {count1}, COUNT2: {count2}")
