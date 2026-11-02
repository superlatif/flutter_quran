import 'package:flutter/material.dart';

import '../services/bookmark_service.dart';
import '../models/bookmark_node.dart';

/// Layar manajemen bookmark pohon hierarki (hingga 3 kedalaman).
class BookmarkTreeScreen extends StatefulWidget {
  const BookmarkTreeScreen({super.key});

  @override
  State<BookmarkTreeScreen> createState() => _BookmarkTreeScreenState();
}

class _BookmarkTreeScreenState extends State<BookmarkTreeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Map<int, List<BookmarkNode>> _childrenMap = <int, List<BookmarkNode>>{};
  int? _expandedNodeId;
  bool _isLoading = true;
  List<BookmarkNode> _nodes = <BookmarkNode>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final List<BookmarkNode> nodes = await BookmarkService.instance.getNodes();
    final Map<int, List<BookmarkNode>> childrenMap =
        <int, List<BookmarkNode>>{};
    for (final BookmarkNode node in nodes) {
      childrenMap[node.id] = await BookmarkService.instance.getChildren(
        node.id,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _nodes = nodes;
      _childrenMap
        ..clear()
        ..addAll(childrenMap);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<BookmarkNode> roots = _nodes
        .where((BookmarkNode node) => node.depth == 1)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Bookmark')),
      body: ListView.builder(
        itemCount: roots.length,
        itemBuilder: (BuildContext context, int index) {
          final BookmarkNode root = roots[index];
          return _buildNodeTile(context, root, 1);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCategoryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNodeTile(BuildContext context, BookmarkNode node, int depth) {
    final bool isExpanded = _expandedNodeId == node.id;
    final List<BookmarkNode> children =
        _childrenMap[node.id] ?? <BookmarkNode>[];

    return Column(
      children: <Widget>[
        ListTile(
          leading: Icon(
            depth == 1
                ? Icons.folder
                : (depth == 2 ? Icons.folder_open : Icons.bookmark),
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(node.name),
          subtitle: Text('Kedalaman ${node.depth}'),
          trailing: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right),
          onTap: () {
            setState(() {
              _expandedNodeId = isExpanded ? null : node.id;
            });
          },
        ),
        if (isExpanded) ...<Widget>[
          ...children.map<Widget>(
            (BookmarkNode child) => _buildNodeTile(context, child, child.depth),
          ),
        ],
      ],
    );
  }

  Future<void> _showCreateCategoryDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    int? parentId;
    int depth = 1;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Kategori Baru'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Induk'),
                    items: _nodes
                        .map<DropdownMenuItem<int>>(
                          (BookmarkNode node) => DropdownMenuItem<int>(
                            value: node.id,
                            child: Text(node.name),
                          ),
                        )
                        .toList(),
                    onChanged: (int? value) {
                      setStateDialog(() {
                        parentId = value;
                        BookmarkNode? parent;
                        for (final BookmarkNode n in _nodes) {
                          if (n.id == value) {
                            parent = n;
                            break;
                          }
                        }
                        depth = (parent?.depth ?? 0) + 1;
                      });
                    },
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori',
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, <String, dynamic>{
                      'name': nameController.text,
                      'parentId': parentId,
                      'depth': depth,
                    });
                  },
                  child: const Text('Buat'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await BookmarkService.instance.createNode(
        parentId: result['parentId'],
        name: result['name'],
        depth: (result['depth'] as int?) ?? 1,
      );
      await _loadData();
    }
  }
}
