import codecs

path = r'lib\features\cashflow\presentation\cashflow_page.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    text = f.read()

# Fix red700
text = text.replace('AppColors.red700', 'AppColors.red600')

# Import
import_stmt = "import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';"
if import_stmt not in text:
    last_import = text.rfind('import ')
    if last_import != -1:
        end_of_line = text.find('\n', last_import)
        text = text[:end_of_line+1] + import_stmt + '\n' + text[end_of_line+1:]

with codecs.open(path, 'w', 'utf-8') as f:
    f.write(text)
print('Fixed imports and color')
