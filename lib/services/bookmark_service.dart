import '../models/bookmark_item.dart';
import '../models/bookmark_node.dart';
import 'database_service.dart';

/// Service untuk manajemen bookmark pohon hierarki (hingga 3 kedalaman)
/// dan bookmark ayat.
class BookmarkService {
  BookmarkService._();

  static final BookmarkService instance = BookmarkService._();

  Future<List<BookmarkNode>> getNodes() async {
    return DatabaseService.instance.getNodes();
  }

  Future<List<BookmarkNode>> getChildren(int? parentId) async {
    return DatabaseService.instance.getChildren(parentId);
  }

  Future<BookmarkNode> createNode({
    int? parentId,
    required String name,
    required int depth,
  }) async {
    return DatabaseService.instance.createNode(
      parentId: parentId,
      name: name,
      depth: depth,
    );
  }

  Future<void> updateNode(int id, String name) async {
    await DatabaseService.instance.updateNode(id, name);
  }

  Future<void> deleteNode(int id) async {
    await DatabaseService.instance.deleteNode(id);
  }

  Future<List<BookmarkItem>> getItemsByNode(int nodeId) async {
    return DatabaseService.instance.getItemsByNode(nodeId);
  }

  Future<List<BookmarkItem>> getAllItems() async {
    return DatabaseService.instance.getAllItems();
  }

  Future<void> createItem({
    required int nodeId,
    required int surahId,
    required int ayahId,
    required int pageNumber,
  }) async {
    await DatabaseService.instance.createItem(
      nodeId: nodeId,
      surahId: surahId,
      ayahId: ayahId,
      pageNumber: pageNumber,
    );
  }

  Future<void> deleteItem(int id) async {
    await DatabaseService.instance.deleteItem(id);
  }
}
