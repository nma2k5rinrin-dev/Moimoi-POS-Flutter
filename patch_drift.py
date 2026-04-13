import os

source_path = r'C:\Users\Efun\AppData\Local\Pub\Cache\hosted\pub.dev\drift_sqflite-2.0.1\lib\drift_sqflite.dart'
dest_path = r'lib\core\database\sqlcipher_executor.dart'

if os.path.exists(source_path):
    with open(source_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Update imports
    content = content.replace("import 'package:sqflite/sqflite.dart' as s;", "import 'package:sqflite_sqlcipher/sqflite.dart' as s;")
    # Also adjust the library name
    content = content.replace("library drift_sqflite;", "library sqlcipher_executor;")

    # 2. Add password parsing to _SqfliteDelegate
    content = content.replace(
        "bool singleInstance;",
        "bool singleInstance;\n  final String? password;"
    )
    content = content.replace(
        "{this.singleInstance = true, this.creator});",
        "{this.singleInstance = true, this.creator, this.password});"
    )

    # 3. Inject password into s.openDatabase
    open_call = """db = await s.openDatabase(
      resolvedPath,
      singleInstance: singleInstance,
    );"""
    replaced_open_call = """db = await s.openDatabase(
      resolvedPath,
      password: password,
      singleInstance: singleInstance,
    );"""
    content = content.replace(open_call, replaced_open_call)

    # 4. Modify SqfliteQueryExecutor to accept password
    content = content.replace(
        "bool singleInstance = true,",
        "bool singleInstance = true,\n      String? password,"
    )
    content = content.replace(
        "singleInstance: singleInstance, creator: creator),",
        "singleInstance: singleInstance, creator: creator, password: password),"
    )
    
    # Let's change the name to SqlCipherQueryExecutor
    content = content.replace("SqfliteQueryExecutor", "SqlCipherQueryExecutor")

    with open(dest_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Success")
else:
    print("Not found")
