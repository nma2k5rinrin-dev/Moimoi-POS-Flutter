import os

def fix_main_shell():
    f = "lib/features/dashboard/presentation/main_shell.dart"
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Remove app_store import
    content = content.replace("import 'package:moimoi_pos/core/state/app_store.dart';", "")
    
    # Fix variables that relied on `data`
    content = content.replace("data.storeInfo", "storeInfo")
    
    # Let's fix the parenthesis matching in build method
    # Since I cannot easily do regex on the PopScope wrapper, I'll just restore the Selector partially, but using context.watch:
    # Actually, the error was: "Expected a class member" at 267. Meaning inside `main_shell.dart`, the parens balance is off.
    # Where did I replace it? Wait, I replaced Selector... but I left `return PopScope(...`
    pass

fix_main_shell()
