import 'package:flutter/material.dart';
import '../providers/tournament_provider.dart';
class CreateTournamentDialog extends StatefulWidget {
  @override
  _CreateTournamentDialogState createState() => _CreateTournamentDialogState();
}

class _CreateTournamentDialogState extends State<CreateTournamentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '16');
  String _selectedGameType = 'Market Master';
  String _selectedTournamentType = 'elimination';
  String _selectedFormat = 'single_elimination';
  
  final List<String> _gameTypes = [
    'Market Master',
    'Consumer Choice',
    'Firm Tycoon',
    'Market Structures',
  ];
  
  final List<String> _tournamentTypes = [
    'elimination',
    'round_robin',
    'swiss',
  ];
  
  final List<String> _formats = [
    'single_elimination',
    'double_elimination',
    'best_of_3',
    'best_of_5',
  ];
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create Tournament'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tournament Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a tournament name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGameType,
                decoration: InputDecoration(
                  labelText: 'Game Type',
                  border: OutlineInputBorder(),
                ),
                items: _gameTypes.map((game) {
                  return DropdownMenuItem(
                    value: game,
                    child: Text(game),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGameType = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTournamentType,
                decoration: InputDecoration(
                  labelText: 'Tournament Type',
                  border: OutlineInputBorder(),
                ),
                items: _tournamentTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTournamentType = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFormat,
                decoration: InputDecoration(
                  labelText: 'Format',
                  border: OutlineInputBorder(),
                ),
                items: _formats.map((format) {
                  return DropdownMenuItem(
                    value: format,
                    child: Text(format),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFormat = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _maxParticipantsController,
                decoration: InputDecoration(
                  labelText: 'Max Participants',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter max participants';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number < 2) {
                    return 'Please enter a valid number (min 2)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // TODO: Create tournament
              Navigator.of(context).pop();
            }
          },
          child: Text('Create'),
        ),
      ],
    );
  }
}
