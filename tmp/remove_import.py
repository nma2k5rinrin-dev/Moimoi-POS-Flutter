import codecs

path = r'lib\features\cashflow\presentation\cashflow_page.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    text = f.read()

text = text.replace("import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';\r\n", '')
text = text.replace("import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';\n", '')

with codecs.open(path, 'w', 'utf-8') as f:
    f.write(text)
print('Removed import')
