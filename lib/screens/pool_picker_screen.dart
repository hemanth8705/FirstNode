import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pool.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'pool_editor_screen.dart';

/// Lists the saved pools. Tapping a pool selects it (returns its id); the Edit
/// button and "+ New" open the [PoolEditorScreen].
class PoolPickerScreen extends StatelessWidget {
  final String? selectedPoolId;
  const PoolPickerScreen({this.selectedPoolId, super.key});

  void _newPool(BuildContext context) {
    final pool = Pool(
      id: 'p${DateTime.now().millisecondsSinceEpoch}',
      name: 'New pool',
      order: PoolOrder.linear,
      songs: [],
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PoolEditorScreen(pool: pool, isNew: true)),
    );
  }

  void _editPool(BuildContext context, Pool pool) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PoolEditorScreen(pool: pool.clone(), isNew: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(
              title: 'Pools',
              trailing: GestureDetector(
                onTap: () => _newPool(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('+ New',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ),
            ),
            Expanded(
              child: app.pools.isEmpty
                  ? Center(
                      child: Text('No pools yet. Tap + New.',
                          style: TextStyle(color: AppColors.w(0.4), fontSize: 15)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children:
                          app.pools.map((p) => _poolRow(context, p)).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _poolRow(BuildContext context, Pool p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.w(0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(p.id),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${p.songs.length} songs · ${p.order.name}',
                      style: TextStyle(color: AppColors.w(0.4), fontSize: 12)),
                ],
              ),
            ),
          ),
          if (selectedPoolId == p.id)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Text('●', style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          GestureDetector(
            onTap: () => _editPool(context, p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.w(0.15)),
              ),
              child: Text('Edit',
                  style: TextStyle(color: AppColors.w(0.7), fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
