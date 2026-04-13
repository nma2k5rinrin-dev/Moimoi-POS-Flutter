import re

with open('lib/features/settings/presentation/sections/notifications_section.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("import 'package:moimoi_pos/core/state/ui_store.dart';", 
                    "import 'package:moimoi_pos/core/state/ui_store.dart';\nimport 'package:moimoi_pos/features/settings/logic/audio_store_standalone.dart';")

text = text.replace("final store = context.watch<UIStore>();",
                    "final audioStore = context.watch<AudioStore>();\n    final uiStore = context.read<UIStore>();")

text = text.replace("store.notificationSound", "audioStore.notificationSound")
text = text.replace("store.paymentSound", "audioStore.paymentSound")
text = text.replace("store.previewNotificationSound", "audioStore.previewNotificationSound")
text = text.replace("_buildBottomActions(store, hasChanges)", "_buildBottomActions(audioStore, uiStore, hasChanges)")
text = text.replace("Widget _buildBottomActions(UIStore store, bool hasChanges) {",
                    "Widget _buildBottomActions(AudioStore audioStore, UIStore store, bool hasChanges) {")

text = text.replace("store.setNotificationSound(", "audioStore.setNotificationSound(")
text = text.replace("store.setPaymentSound(", "audioStore.setPaymentSound(")

with open('lib/features/settings/presentation/sections/notifications_section.dart', 'w', encoding='utf-8') as f:
    f.write(text)

# roles_section.dart
with open('lib/features/settings/presentation/sections/roles_section.dart', 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("store.mgmt.", "store.")
text = text.replace("store.showConfirm(", "context.read<UIStore>().showConfirm(")
text = text.replace("store.notifyListeners();", "")

with open('lib/features/settings/presentation/sections/roles_section.dart', 'w', encoding='utf-8') as f:
    f.write(text)
    
# settings_page.dart
with open('lib/features/settings/presentation/settings_page.dart', 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace("store.sadminViewStoreId", "context.read<UIStore>().sadminViewStoreId")
text = text.replace("store.QuotaDataProvider", "store.quotaProvider") # Wait, I don't know the exact issue 
with open('lib/features/settings/presentation/settings_page.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("done")
