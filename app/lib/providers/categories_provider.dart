import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/category.dart';

final categoriesProvider = AsyncNotifierProvider<CategoriesNotifier, List<Category>>(CategoriesNotifier.new);

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() => _fetch();

  Future<List<Category>> _fetch() async {
    final res = await ApiClient.instance.dio.get('/categories');
    return (res.data as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addCategory(Category category) async {
    await ApiClient.instance.dio.post('/categories', data: category.toJson());
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateCategory(String id, Category category) async {
    await ApiClient.instance.dio.put('/categories/$id', data: category.toJson());
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteCategory(String id) async {
    await ApiClient.instance.dio.delete('/categories/$id');
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
