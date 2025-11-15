import 'package:flutter/material.dart';

/// Widget de table de données réutilisable
class DataTableWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  
  const DataTableWidget({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('Aucune donnée à afficher'),
      );
    }

    // Extraire les colonnes depuis la première ligne
    final columns = data.first.keys.toList();
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: columns.map((column) => DataColumn(
              label: Text(
                column.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )).toList(),
            rows: data.map((row) => DataRow(
              cells: columns.map((column) => DataCell(
                Text(
                  row[column]?.toString() ?? 'NULL',
                  style: TextStyle(
                    color: row[column] == null ? Colors.grey : null,
                  ),
                ),
              )).toList(),
            )).toList(),
          ),
        ),
      ),
    );
  }
}
