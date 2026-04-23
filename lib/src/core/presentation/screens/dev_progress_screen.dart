import 'package:flutter/material.dart';
import '../../utils/page_registry.dart';

class DevProgressScreen extends StatelessWidget {
  const DevProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = PageRegistry.items;
    final total = items.length;
    final uiOnly = items.where((i) => i.stage == 'UIOnly').length;
    final wired = items.where((i) => i.stage == 'Wired').length;
    final connected = items.where((i) => i.stage == 'Connected').length;
    final done = items.where((i) => i.stage == 'Done').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Progress'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '$done/$total Done',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(total, uiOnly, wired, connected, done),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: _buildStageIcon(item.stage),
                  title: Text(item.routeName),
                  subtitle: Text('${item.module} - ${item.screenClassName}'),
                  trailing: Chip(
                    label: Text(item.stage),
                    backgroundColor: _getStageColor(item.stage),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      int total, int uiOnly, int wired, int connected, int done) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat('Total', total, Colors.black),
            _buildStat('UIOnly', uiOnly, Colors.blue),
            _buildStat('Wired', wired, Colors.orange),
            _buildStat('Conn.', connected, Colors.purple),
            _buildStat('Done', done, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Icon _buildStageIcon(String stage) {
    switch (stage) {
      case 'Done':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'Connected':
        return const Icon(Icons.link, color: Colors.purple);
      case 'Wired':
        return const Icon(Icons.electrical_services, color: Colors.orange);
      default:
        return const Icon(Icons.design_services, color: Colors.blue);
    }
  }

  Color _getStageColor(String stage) {
    switch (stage) {
      case 'Done':
        return Colors.green.shade100;
      case 'Connected':
        return Colors.purple.shade100;
      case 'Wired':
        return Colors.orange.shade100;
      default:
        return Colors.blue.shade100;
    }
  }
}
