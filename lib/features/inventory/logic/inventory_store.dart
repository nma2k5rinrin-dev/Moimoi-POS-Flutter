import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/features/inventory/models/product_model.dart';
import 'package:moimoi_pos/features/inventory/models/category_model.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';

mixin InventoryStore on ChangeNotifier, BaseMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, List<CategoryModel>> categories = {'sadmin': []};
  Map<String, List<ProductModel>> products = {'sadmin': []};

  RealtimeChannel? _productsChannel;
  RealtimeChannel? _categoriesChannel;

  List<CategoryModel> getStoreCategories(String storeId) =>
      categories[storeId] ?? [];
  List<ProductModel> getStoreProducts(String storeId) =>
      products[storeId] ?? [];

  void clearInventoryState() {
    categories = {'sadmin': []};
    products = {'sadmin': []};
    _productsChannel?.unsubscribe();
    _categoriesChannel?.unsubscribe();
  }
}
