import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:moimoi_pos/features/inventory/models/product_model.dart';
import 'package:moimoi_pos/features/inventory/models/category_model.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:moimoi_pos/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:moimoi_pos/core/utils/quota_helper.dart';
import 'package:moimoi_pos/features/premium/presentation/widgets/upgrade_dialog.dart';

/// Manages Categories and Products CRUD operations.
class InventoryStore extends ChangeNotifier with BaseMixin {
  final QuotaDataProvider quotaProvider;

  InventoryStore(this.quotaProvider);

  @override
  String getStoreId() => quotaProvider.getStoreId();
  // ── State ─────────────────────────────────────────────────
  Map<String, List<CategoryModel>> categories = {'sadmin': []};
  Map<String, List<ProductModel>> products = {'sadmin': []};

  List<CategoryModel> getStoreCategories(String storeId) =>
      categories[storeId] ?? [];
  List<ProductModel> getStoreProducts(String storeId) =>
      products[storeId] ?? [];

  List<CategoryModel> get currentCategories => categories[getStoreId()] ?? [];
  List<ProductModel> get currentProducts => products[getStoreId()] ?? [];

  void clearInventoryState() {
    categories = {'sadmin': []};
    products = {'sadmin': []};
  }

  Future<void> initInventoryStore(String? storeId) async {
    if (storeId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString('lastSyncTime_');

      categories[storeId] = [];
      products[storeId] = [];

      bool hasLocalData = false;

      // 1. Tải dữ liệu toàn bộ từ SQLite lên RAM ngay lập tức (Xử lý Offline và Load Nhanh)
      if (db != null) {
        final localCats = await db!.getCategoriesByStore(storeId);
        if (localCats.isNotEmpty) {
          categories[storeId] = localCats
              .map(
                (c) => CategoryModel(
                  id: c.id,
                  storeId: c.storeId,
                  name: c.name,
                  emoji: c.emoji,
                  color: c.color,
                ),
              )
              .toList();
        }

        final localProds = await db!.getProductsByStore(storeId);
        if (localProds.isNotEmpty) {
          hasLocalData = true;
          products[storeId] = localProds
              .map(
                (p) => ProductModel(
                  id: p.id,
                  storeId: p.storeId,
                  name: p.name,
                  price: p.price,
                  image: p.image,
                  category: p.category,
                  description: p.description,
                  isOutOfStock: p.isOutOfStock,
                  isHot: p.isHot,
                  quantity: p.quantity,
                  costPrice: p.costPrice,
                ),
              )
              .toList();
        }
      }

      // 2. Chạy Sync Mạng
      // Nếu có sẵn DB local, chạy ngầm (trả về Future ngay lập tức) để UI load mượt.
      // Nếu là cài đặt mới (hoặc Wipe Data), bắt buộc phải await tải toàn bộ lần đầu.
      final networkSyncFuture = _executeDeltaSync(storeId, lastSyncStr, prefs);

      if (!hasLocalData) {
        await networkSyncFuture;
      } else {
        // Fire & forget: chạy ngầm update background
        networkSyncFuture.catchError((e) => debugPrint('[InventorySync] Bg Error: $e'));
      }

    } catch (e) {
      debugPrint('[initInventoryStore] $e');
    }
  }

  Future<void> _executeDeltaSync(String storeId, String? lastSyncStr, SharedPreferences prefs) async {
    try {
      var catQuery = supabaseClient
          .from('categories')
          .select()
          .eq('store_id', storeId)
          .isFilter('deleted_at', null);

      final role = prefs.getString('role') ?? 'staff';
      final isManager = role == 'admin' || role == 'sadmin';

      var prodQuery = supabaseClient
          .from('products')
          .select(isManager 
              ? 'id, store_id, name, price, image, category, description, is_out_of_stock, is_hot, quantity, cost_price, unit, updated_at'
              : 'id, store_id, name, price, image, category, description, is_out_of_stock, is_hot, unit, updated_at')
          .eq('store_id', storeId)
          .isFilter('deleted_at', null);

      if (lastSyncStr != null && products[storeId]!.isNotEmpty) {
        catQuery = catQuery.gt('updated_at', lastSyncStr);
        prodQuery = prodQuery.gt('updated_at', lastSyncStr);
      }

      final results = await Future.wait([
        catQuery.catchError((e) { debugPrint('Categories error: $e'); return <Map<String,dynamic>>[]; }),
        prodQuery.catchError((e) { debugPrint('Products error: $e'); return <Map<String,dynamic>>[]; })
      ]);
      
      final fetchedCats = results[0] as List;
      final fetchedProds = results[1] as List;

      if (fetchedCats.isEmpty && fetchedProds.isEmpty && lastSyncStr != null) {
        notifyListeners();
        return;
      }

      // 3. Trộn (Merge) thay đổi mới từ Server vào bộ nhớ
      for (final c in fetchedCats) {
        final cat = CategoryModel.fromMap(c);
        if (db != null) {
          final hasPending = await db!.hasPendingSync(cat.id);
          if (hasPending) continue; // Bỏ qua ghi đè nếu đang chờ đẩy lên
        }
        final idx = categories[storeId]!.indexWhere((item) => item.id == cat.id);
        if (idx != -1) categories[storeId]![idx] = cat;
        else categories[storeId]!.add(cat);
      }

      for (final p in fetchedProds) {
        final prod = ProductModel.fromMap(p);
        if (db != null) {
          final hasPending = await db!.hasPendingSync(prod.id);
          if (hasPending) continue; // Bỏ qua ghi đè nếu đang chờ đẩy lên
        }
        final idx = products[storeId]!.indexWhere((item) => item.id == prod.id);
        if (idx != -1) products[storeId]![idx] = prod;
        else products[storeId]!.add(prod);
      }

      await prefs.setString('lastSyncTime_', DateTime.now().toUtc().toIso8601String());

      // 4. Lưu bù vào SQLite
      if (db != null) {
        final List<LocalCategoriesCompanion> catCompanions = [];
        for (final c in categories[storeId]!) {
          final hasPending = await db!.hasPendingSync(c.id);
          if (!hasPending) {
            catCompanions.add(LocalCategoriesCompanion(
              id: Value(c.id), name: Value(c.name), storeId: Value(c.storeId),
              emoji: Value(c.emoji), color: Value(c.color),
              isSynced: const Value(true),
            ));
          }
        }

        if (catCompanions.isNotEmpty) {
          await db!.replaceAllCategories(storeId, catCompanions);
        }

        final List<LocalProductsCompanion> prodCompanions = [];
        for (final p in products[storeId]!) {
          final hasPending = await db!.hasPendingSync(p.id);
          if (!hasPending) {
            prodCompanions.add(LocalProductsCompanion(
              id: Value(p.id), storeId: Value(p.storeId), name: Value(p.name),
              price: Value(p.price), image: Value(p.image), category: Value(p.category),
              description: Value(p.description), isOutOfStock: Value(p.isOutOfStock),
              isHot: Value(p.isHot), quantity: Value(p.quantity), costPrice: Value(p.costPrice),
              isSynced: const Value(true),
            ));
          }
        }

        if (prodCompanions.isNotEmpty) {
          await db!.replaceAllProducts(storeId, prodCompanions);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[_executeDeltaSync] error: $e');
    }
  }

  // ── Categories CRUD ───────────────────────────────────────
  Future<bool> addCategory(
    String categoryName, {
    String emoji = '',
    String color = '',
    String description = '',
  }) async {
    final quota = QuotaHelper(quotaProvider);
    if (!quota.canAddCategory) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.categoryLimitMsg);
      return false;
    }
    final storeId = getStoreId();
    final newId = const Uuid().v4();
    final newCat = {
      'id': newId,
      'store_id': storeId,
      'name': categoryName,
      'emoji': emoji,
      'color': color,
      'description': description,
    };
    final catModel = CategoryModel.fromMap(newCat);
    optimistic(
      apply: () {
        categories.putIfAbsent(storeId, () => []);
        categories[storeId]!.add(catModel);
      },
      remote: () async {
        if (db != null) {
          final txId = DateTime.now().millisecondsSinceEpoch.toString();
          await db!.upsertCategory(
            LocalCategoriesCompanion(
              id: Value(newCat['id'] as String),
              storeId: Value(storeId),
              name: Value(categoryName),
              emoji: Value(emoji),
              color: Value(color),
              isSynced: const Value(false),
            ),
          );
          await db!.enqueueSyncOp(
            txId: txId,
            tableName: 'categories',
            operation: 'INSERT',
            recordId: newCat['id'] as String,
            payload: jsonEncode(newCat),
          );
          syncEngine?.syncAll();
        } else {
          await supabaseClient.from('categories').insert(newCat);
        }
      },
      rollback: () {
        categories[storeId]?.removeWhere((c) => c.id == catModel.id);
      },
      errorMsg: 'Thêm danh mục thất bại, đã hoàn tác',
    );
    return true;
  }

  void updateCategory(CategoryModel updatedCategory) {
    final storeId = getStoreId();
    final oldCategories = List<CategoryModel>.from(categories[storeId] ?? []);
    optimistic(
      apply: () {
        categories[storeId] = (categories[storeId] ?? [])
            .map((c) => c.id == updatedCategory.id ? updatedCategory : c)
            .toList();
      },
      remote: () async {
        if (db != null) {
          final txId = DateTime.now().millisecondsSinceEpoch.toString();
          
          final payload = {
            'name': updatedCategory.name,
            'emoji': updatedCategory.emoji,
            'color': updatedCategory.color,
            'description': updatedCategory.description,
          };
          
          await db!.upsertCategory(
            LocalCategoriesCompanion(
              id: Value(updatedCategory.id),
              storeId: Value(storeId),
              name: Value(updatedCategory.name),
              emoji: Value(updatedCategory.emoji),
              color: Value(updatedCategory.color),
              isSynced: const Value(false),
            ),
          );
          await db!.enqueueSyncOp(
            txId: txId,
            tableName: 'categories',
            operation: 'UPDATE',
            recordId: updatedCategory.id,
            payload: jsonEncode(payload),
          );
          syncEngine?.syncAll();
        } else {
          final payload = {
            'name': updatedCategory.name,
            'emoji': updatedCategory.emoji,
            'color': updatedCategory.color,
            'description': updatedCategory.description,
          };
          await supabaseClient.from('categories').update(payload).eq('id', updatedCategory.id);
        }
      },
      rollback: () {
        categories[storeId] = oldCategories;
      },
      errorMsg: 'Cập nhật danh mục thất bại, đã hoàn tác',
    );
  }

  void deleteCategory(String categoryId) {
    final storeId = getStoreId();
    final oldCategories = List<CategoryModel>.from(categories[storeId] ?? []);
    final oldProducts = List<ProductModel>.from(products[storeId] ?? []);
    optimistic(
      apply: () {
        categories[storeId]?.removeWhere((c) => c.id == categoryId);
        if (products[storeId] != null) {
          products[storeId] = products[storeId]!.map((p) {
            return p.category == categoryId ? p.copyWith(category: '') : p;
          }).toList();
        }
      },
      remote: () async {
        if (db != null) {
          final txId = DateTime.now().millisecondsSinceEpoch.toString();
          
          final payload = {
             'deleted_at': DateTime.now().toUtc().toIso8601String()
          };
          
          await db!.deleteCategoryLocally(categoryId);
          
          await db!.enqueueSyncOp(
            txId: txId,
            tableName: 'categories',
            operation: 'UPDATE', // Soft delete is basically UPDATE deleted_at
            recordId: categoryId,
            payload: jsonEncode(payload),
          );
          
          // Cascading changes to products that had this category locally
          final productsToUpdate = oldProducts.where((p) => p.category == categoryId).toList();
          for (final p in productsToUpdate) {
             final pTxId = 'prod_${DateTime.now().microsecondsSinceEpoch}';
             await db!.enqueueSyncOp(
               txId: pTxId,
               tableName: 'products',
               operation: 'UPDATE',
               recordId: p.id,
               payload: jsonEncode({'category': ''}),
             );
          }
          syncEngine?.syncAll();
        } else {
          final payload = {
             'deleted_at': DateTime.now().toUtc().toIso8601String()
          };
          await supabaseClient.from('categories').update(payload).eq('id', categoryId);
          final productsToUpdate = oldProducts.where((p) => p.category == categoryId).toList();
          if (productsToUpdate.isNotEmpty) {
            await supabaseClient.from('products').update({'category': ''}).eq('store_id', storeId).eq('category', categoryId);
          }
        }
      },
      rollback: () {
        categories[storeId] = oldCategories;
        products[storeId] = oldProducts;
      },
      errorMsg: 'Xoá danh mục thất bại, đã hoàn tác',
    );
  }

  // ── Products CRUD ─────────────────────────────────────────
  Future<String> _uploadBase64ImageToStorage(
    String storeId,
    String base64String,
  ) async {
    try {
      if (!base64String.startsWith('data:')) return base64String;

      final url = await CloudflareService.uploadBase64(
        base64Data: base64String,
        folder: 'products',
      );

      return url;
    } catch (e) {
      debugPrint('[InventoryStore] Lỗi upload ảnh sản phẩm qua R2: $e');
      return base64String;
    }
  }

  Future<bool> addProduct(ProductModel product) async {
    final quota = QuotaHelper(quotaProvider);
    if (!quota.canAddProduct) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.productLimitMsg);
      return false;
    }
    final storeId = getStoreId();
    final newId = const Uuid().v4();
    final newProd = {
      'id': newId,
      'store_id': storeId,
      'name': product.name,
      'price': product.price,
      'image': product.image,
      'category': product.category,
      'description': product.description,
      'is_out_of_stock': product.isOutOfStock,
      'is_hot': product.isHot,
      'quantity': product.quantity,
      'cost_price': product.costPrice,
      'unit': product.unit,
    };
    final newProduct = product.copyWith(
      id: newProd['id'] as String,
      storeId: storeId,
    );
    optimistic(
      apply: () {
        products.putIfAbsent(storeId, () => []);
        products[storeId]!.insert(0, newProduct);
      },
      remote: () async {
        final publicUrl = await _uploadBase64ImageToStorage(
          storeId,
          product.image,
        );
        newProd['image'] = publicUrl;
        final index = products[storeId]?.indexWhere(
          (p) => p.id == newProduct.id,
        );
        if (index != null && index != -1) {
          products[storeId]![index] = newProduct.copyWith(image: publicUrl);
          notifyListeners();
        }
        
        if (db != null) {
          final txId = DateTime.now().millisecondsSinceEpoch.toString();
          await db!.upsertProduct(
            LocalProductsCompanion(
              id: Value(newProd['id'] as String),
              storeId: Value(storeId),
              name: Value(newProd['name'] as String),
              price: Value(newProd['price'] as double),
              image: Value(publicUrl),
              category: Value(newProd['category'] as String),
              description: Value(newProd['description'] as String),
              isOutOfStock: Value(newProd['is_out_of_stock'] as bool),
              isHot: Value(newProd['is_hot'] as bool),
              quantity: Value(newProd['quantity'] as int),
              costPrice: Value(newProd['cost_price'] as double),
              isSynced: const Value(false),
            ),
          );
          await db!.enqueueSyncOp(
            txId: txId,
            tableName: 'products',
            operation: 'INSERT',
            recordId: newProd['id'] as String,
            payload: jsonEncode(newProd),
          );
          syncEngine?.syncAll();
        } else {
          await supabaseClient.from('products').insert(newProd);
        }
      },
      rollback: () {
        products[storeId]?.removeWhere((p) => p.id == newProduct.id);
      },
      errorMsg: 'Thêm sản phẩm thất bại, đã hoàn tác',
    );
    return true;
  }

  void updateProduct(ProductModel updatedProduct) {
    final storeId = getStoreId();
    final oldProducts = List<ProductModel>.from(products[storeId] ?? []);
    optimistic(
      apply: () {
        products[storeId] = (products[storeId] ?? [])
            .map((p) => p.id == updatedProduct.id ? updatedProduct : p)
            .toList();
      },
      remote: () async {
        final publicUrl = await _uploadBase64ImageToStorage(
          storeId,
          updatedProduct.image,
        );
        if (publicUrl != updatedProduct.image) {
          final index = products[storeId]?.indexWhere(
            (p) => p.id == updatedProduct.id,
          );
          if (index != null && index != -1) {
            products[storeId]![index] = updatedProduct.copyWith(
              image: publicUrl,
            );
            notifyListeners();
          }
        }
        if (db != null) {
          final txId = DateTime.now().millisecondsSinceEpoch.toString();
          
          final payload = {
            'name': updatedProduct.name,
            'price': updatedProduct.price,
            'image': publicUrl,
            'category': updatedProduct.category,
            'description': updatedProduct.description,
            'is_out_of_stock': updatedProduct.isOutOfStock,
            'is_hot': updatedProduct.isHot,
            'quantity': updatedProduct.quantity,
            'cost_price': updatedProduct.costPrice,
            'unit': updatedProduct.unit,
          };
          
          await db!.upsertProduct(
            LocalProductsCompanion(
              id: Value(updatedProduct.id),
              storeId: Value(storeId),
              name: Value(updatedProduct.name),
              price: Value(updatedProduct.price),
              image: Value(publicUrl),
              category: Value(updatedProduct.category),
              description: Value(updatedProduct.description),
              isOutOfStock: Value(updatedProduct.isOutOfStock),
              isHot: Value(updatedProduct.isHot),
              quantity: Value(updatedProduct.quantity),
              costPrice: Value(updatedProduct.costPrice),
              isSynced: const Value(false),
            ),
          );
          await db!.enqueueSyncOp(
            txId: txId,
            tableName: 'products',
            operation: 'UPDATE',
            recordId: updatedProduct.id,
            payload: jsonEncode(payload),
          );
          syncEngine?.syncAll();
        } else {
          final payload = {
            'name': updatedProduct.name,
            'price': updatedProduct.price,
            'image': publicUrl,
            'category': updatedProduct.category,
            'description': updatedProduct.description,
            'is_out_of_stock': updatedProduct.isOutOfStock,
            'is_hot': updatedProduct.isHot,
            'quantity': updatedProduct.quantity,
            'cost_price': updatedProduct.costPrice,
            'unit': updatedProduct.unit,
          };
          await supabaseClient.from('products').update(payload).eq('id', updatedProduct.id);
        }
      },
      rollback: () {
        products[storeId] = oldProducts;
      },
      errorMsg: 'Cập nhật sản phẩm thất bại, đã hoàn tác',
    );
  }

  void deleteProduct(String productId) {
    final storeId = getStoreId();
    final oldProducts = List<ProductModel>.from(products[storeId] ?? []);
    optimistic(
      apply: () {
        products[storeId]?.removeWhere((p) => p.id == productId);
      },
      remote: () async {
        if (db != null) {
          final txId = DateTime.now().millisecondsSinceEpoch.toString();
          
          final payload = {
             'deleted_at': DateTime.now().toUtc().toIso8601String()
          };
          
          await db!.deleteProductLocally(productId);
          
          await db!.enqueueSyncOp(
            txId: txId,
            tableName: 'products',
            operation: 'UPDATE', // Soft delete is basically UPDATE deleted_at
            recordId: productId,
            payload: jsonEncode(payload),
          );
          syncEngine?.syncAll();
        } else {
          final payload = {
             'deleted_at': DateTime.now().toUtc().toIso8601String()
          };
          await supabaseClient.from('products').update(payload).eq('id', productId);
        }
      },
      rollback: () {
        products[storeId] = oldProducts;
      },
      errorMsg: 'Xoá sản phẩm thất bại, đã hoàn tác',
    );
  }
}
