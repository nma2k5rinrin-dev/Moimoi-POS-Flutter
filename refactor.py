import re

def move_method(source_file, target_file, method_names):
    with open(source_file, 'r', encoding='utf-8') as f:
        content = f.read()

    extracted_methods = []
    
    for method in method_names:
        # Match from "  Future<void> methodName" to the end of the method
        # This matches balanced braces for the method
        pattern = r'(?:  |)(?:Future(?:<[^>]*>)? |void |List<[^>]*> |[A-Za-z0-9_]+ )(?:get )?' + method + r'(?:\(.*?\))?\s*\{(?:[^{}]|(?:\{(?:[^{}]|(?:\{[^{}]*\}))*\}))*}'
        
        # A more robust brace-matching approach for Python:
        # Since regex for arbitrary unbounded balanced braces is hard, we can parse it manually.
        pass

    # We will just parse the file linearly to find the methods.
    def extract(text, m_name):
        # find the index
        idx = text.find(m_name)
        if idx == -1: return text, ""
        
        # backtrack to the start of the line or modifiers
        start_idx = text.rfind('\n', 0, idx)
        if start_idx == -1: start_idx = 0
        
        # find the first '{'
        brace_start = text.find('{', idx)
        if brace_start == -1: return text, ""
        
        # brace matching
        count = 1
        curr = brace_start + 1
        while count > 0 and curr < len(text):
            if text[curr] == '{': count += 1
            elif text[curr] == '}': count -= 1
            curr += 1
            
        end_idx = curr
        
        method_str = text[start_idx:end_idx]
        new_text = text[:start_idx] + text[end_idx:]
        return new_text, method_str

    for method in method_names:
        content, method_text = extract(content, method + '(')
        if not method_text:
            content, method_text = extract(content, method + ' ') # for getters
        if method_text:
            extracted_methods.append(method_text.strip())

    with open(source_file, 'w', encoding='utf-8') as f:
        f.write(content)

    if extracted_methods:
        with open(target_file, 'r', encoding='utf-8') as f:
            target_content = f.read()
            
        # insert before the last '}'
        last_brace_idx = target_content.rfind('}')
        if last_brace_idx != -1:
            new_target = target_content[:last_brace_idx] + '\n\n  ' + '\n\n  '.join(extracted_methods) + '\n}\n'
            with open(target_file, 'w', encoding='utf-8') as f:
                f.write(new_target)

# Move inventory methods
move_method('lib/core/state/app_store.dart', 'lib/features/inventory/logic/inventory_store.dart', [
    'addCategory', 'updateCategory', 'deleteCategory', 'reorderCategories',
    'addProduct', 'updateProduct', 'deleteProduct'
])

# Move order methods
move_method('lib/core/state/app_store.dart', 'lib/features/pos_order/logic/order_store.dart', [
    'addToCart', 'updateCartQuantity', 'updateCartNote', 'clearCart', 
    'addOrder', 'deleteOrder', 'updateOrder', 'updateOrderItemStatus',
    'addOrderToDraft', 'removeOrderFromDraft'
])

# Move cashflow methods to a new file or ManagementStore? There isn't CashflowStore mixed in.
# Let's pause and check if there are compilation errors.
print("Done")
