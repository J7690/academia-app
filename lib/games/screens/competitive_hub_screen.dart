import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tournament_service.dart';
import '../services/league_service.dart';
import '../services/matchmaking_service.dart';
import '../utils/game_constants.dart';
import '../providers/game_provider.dart';

/// Écran principal des tournois et ligues Kellenge
class CompetitiveHubScreen extends StatefulWidget {
  const CompetitiveHubScreen({super.key});

  @override
  State<CompetitiveHubScreen> createState() => _CompetitiveHubScreenState();
}

class _CompetitiveHubScreenState extends State<CompetitiveHubScreen>
    with TickerProviderStateMixin {
  final TournamentService _tournamentService = TournamentService.instance;
  final LeagueService _leagueService = LeagueService.instance;
  
  int _selectedIndex = 0;
  List<Tournament> _tournaments = [];
  List<League> _leagues = [];
  bool _isLoading = false;
  String? _selectedGameType;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final tournaments = await _tournamentService.listAvailableTournaments(
      gameType: _selectedGameType,
      limit: 20,
    );
    
    final leagues = await _leagueService.listAvailableLeagues(
      gameType: _selectedGameType,
      limit: 20,
    );
    
    setState(() {
      _tournaments = tournaments;
      _leagues = leagues;
      _isLoading = false;
    });
  }
  
  Future<void> _createTournament() async {
    final result = await _showCreateTournamentDialog();
    if (result.success) {
      _loadData();
      _showSuccessMessage('Tournament created successfully!');
    } else {
      _showErrorMessage(result.message);
    }
  }
  
  Future<void> _showCreateTournamentDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final maxParticipantsController = TextEditingController(text: '16');
    final prizePoolController = TextEditingController(text: '1000');
    final entryFeeController = TextEditingController(text: '0');
    final registrationEndController = TextEditingController();
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();
    
    String tournamentType = 'elimination';
    String format = 'single_elimination';
    bool isFeatured = false;
    bool isPrivate = false;
    int eloMin = 0;
    int eloMax = 3000;
    
    return showDialog<TournamentResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Tournament'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tournament Name',
                  hintText: 'Enter tournament name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter tournament description',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGameType,
                decoration: const InputDecoration(
                  labelText: 'Game Type',
                ),
                items: GameConstants.gameTypes.map((game) {
                  return DropdownMenuItem(
                    value: game,
                    child: Text(game),
                  );
                }).toList(),
                onChanged: (value) => _selectedGameType = value,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: tournamentType,
                decoration: const InputDecoration(
                  labelText: 'Tournament Type',
                ),
                items: const [
                  DropdownMenuItem(value: 'elimination', child: Text('Elimination')),
                  DropdownMenuItem(value: 'round_robin', child: Text('Round Robin')),
                  DropdownMenuItem(value: 'swiss', child: Text('Swiss System')),
                  DropdownMenuItem(value: 'group_stage', child: Text('Group Stage')),
                ],
                onChanged: (value) => tournamentType = value!,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: format,
                decoration: const InputDecoration(
                  labelText: 'Format',
                ),
                items: const [
                  DropdownMenuItem(value: 'single_elimination', child: Text('Single Elimination')),
                  DropdownMenuItem(value: 'double_elimination', child: Text('Double Elimination')),
                  DropdownMenuItem(value: 'best_of_3', child: Text('Best of 3')),
                  DropdownMenuItem(value: 'best_of_5', child: Text('Best of 5')),
                ],
                onChanged: (value) => format = value!,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: maxParticipantsController,
                      decoration: const InputDecoration(
                        labelText: 'Max Participants',
                        hintText: '16',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: prizePoolController,
                      decoration: const InputDecoration(
                        labelText: 'Prize Pool',
                        hintText: '1000',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: entryFeeController,
                      decoration: const InputDecoration(
                        labelText: 'Entry Fee',
                        hintText: '0',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: registrationEndController,
                      decoration: const InputDecoration(
                        labelText: 'Registration End',
                        hintText: '24 hours from now',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startDateController,
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        hintText: 'Tomorrow',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: endDateController,
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        hintText: '3 days from start',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: isFeatured,
                    onChanged: (value) => isFeatured = value,
                  ),
                  const Text('Featured Tournament'),
                  const Spacer(),
                  Checkbox(
                    value: isPrivate,
                    onChanged: (value) => isPrivate = value,
                  ),
                  const Text('Private Tournament'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'ELO Range',
                        hintText: '0 - 3000',
                      ),
                      controller: TextEditingController(text: '$eloMin - $eloMax'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await _tournamentService.createTournament(
                name: nameController.text,
                description: descriptionController.text,
                gameType: _selectedGameType!,
                tournamentType: tournamentType,
                format: format,
                maxParticipants: int.tryParse(maxParticipantsController.text) ?? 16,
                minParticipants: 4,
                registrationEnd: registrationEndController.text.isNotEmpty 
                    ? DateTime.parse(registrationEndController.text)
                    : DateTime.now().add(const Duration(hours: 24)),
                startDate: startDateController.text.isNotEmpty 
                    ? DateTime.parse(startDateController.text)
                    : DateTime.now().add(const Duration(days: 1)),
                endDate: endDateController.text.isNotEmpty 
                    ? DateTime.parse(endDateController.text)
                    : DateTime.now().add(const Duration(days: 3)),
                prizePool: int.tryParse(prizePoolController.text) ?? 1000,
                entryFee: int.tryParse(entryFeeController.text) ?? 0,
                isFeatured: isFeatured,
                isPrivate: isPrivate,
                eloMin: eloMin,
                eloMax: eloMax,
              );
              
              Navigator.pop(context);
              Navigator.pop(result);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _createLeague() async {
    final result = await _showCreateLeagueDialog();
    if (result.success) {
      _loadData();
      _showSuccessMessage('League created successfully!');
    } else {
      _showErrorMessage(result.message);
    }
  }
  
  Future<LeagueResult> _showCreateLeagueDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final maxPlayersController = TextEditingController(text: '1000');
    final seasonEndController = TextEditingController();
    final promotionCountController = TextEditingController(text: '2');
    final relegationCountController = TextEditingController(text: '2');
    
    String leagueType = 'seasonal';
    String division = 'main';
    int seasonNumber = 1;
    int minElo = 0;
    int maxElo = 3000;
    
    return showDialog<LeagueResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create League'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'League Name',
                  hintText: 'Enter league name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter league description',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGameType,
                decoration: const InputDecoration(
                  labelText: 'Game Type',
                ),
                items: GameConstants.gameTypes.map((game) {
                  return DropdownMenuItem(
                    value: game,
                    child: Text(game),
                  );
                }).toList(),
                onChanged: (value) => _selectedGameType = value,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: leagueType,
                decoration: const InputDecoration(
                  labelText: 'League Type',
                ),
                items: const [
                  DropdownMenuItem(value: 'seasonal', child: Text('Seasonal')),
                  DropdownMenuItem(value: 'ranked', child: Text('Ranked')),
                  DropdownMenuItem(value: 'casual', child: Text('Casual')),
                ],
                onChanged: (value) => leagueType = value!,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: division,
                decoration: const InputDecoration(
                  labelText: 'Division',
                ),
                items: const [
                  DropdownMenuItem(value: 'bronze', child: Text('Bronze')),
                  DropdownMenuItem(value: 'silver', child: Text('Silver')),
                  DropdownMenuItem(value: 'gold', child: Text('Gold')),
                  DropdownMenuItem(value: 'platinum', child: Text('Platinum')),
                  DropdownMenuItem(value: 'diamond', child: Text('Diamond')),
                  DropdownMenuItem(value: 'main', child: Text('Main')),
                ],
                onChanged: (value) => division = value!,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: maxPlayersController,
                      decoration: const InputDecoration(
                        labelText: 'Max Players',
                        hintText: '1000',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: seasonEndController,
                      decoration: const InputDecoration(
                        labelText: 'Season End',
                        hintText: '3 months from now',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: promotionCountController,
                      decoration: const InputDecoration(
                        labelText: 'Promotion Count',
                        hintText: '2',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: relegationCountController,
                      decoration: const InputDecoration(
                        labelText: 'Relegation Count',
                        hintText: '2',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'ELO Range',
                        hintText: '0 - 3000',
                      ),
                      controller: TextEditingController(text: '$minElo - $maxElo'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await _leagueService.createLeague(
                name: nameController.text,
                description: descriptionController.text,
                gameType: _selectedGameType!,
                leagueType: leagueType,
                division: division,
                seasonNumber: seasonNumber,
                seasonEnd: seasonEndController.text.isNotEmpty 
                    ? DateTime.parse(seasonEndController.text)
                    : DateTime.now().add(const Duration(days: 90)),
                maxPlayers: int.tryParse(maxPlayersController.text) ?? 1000,
                minElo: minElo,
                maxElo: maxElo,
                promotionCount: int.tryParse(promotionCountController.text) ?? 2,
                relegationCount: int.tryParse(relegationCountController.text) ?? 2,
              );
              
              Navigator.pop(context);
              Navigator.pop(result);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showTournamentDetails(Tournament tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentDetailScreen(tournament: tournament),
      ),
    );
  }
  
  void _showLeagueDetails(League league) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeagueDetailScreen(league: league),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Competitive Play'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _selectedIndex == 0 ? _createTournament() : _createLeague(),
            tooltip: _selectedIndex == 0 ? 'Create Tournament' : 'Create League',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header avec sélection de jeu et tabs
          _buildHeader(),
          
          // Contenu principal
          Expanded(
            child: _selectedIndex == 0 ? _buildTournamentsList() : _buildLeaguesList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Game Type',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: GameConstants.gameTypes.map((gameType) {
                final isSelected = _selectedGameType == gameType;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(gameType),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedGameType = selected ? gameType : null;
                        _loadData();
                      });
                    },
                    backgroundColor: isSelected ? Colors.purple : Colors.grey[300],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Tabs
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedIndex == 0 ? Colors.purple[600] : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Tournaments',
                        style: TextStyle(
                          color: _selectedIndex == 0 ? Colors.white : Colors.black87,
                          fontWeight: _selectedIndex == 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedIndex == 1 ? Colors.purple[600] : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Leagues',
                        style: TextStyle(
                          color: _selectedIndex == 1 ? Colors.white : Colors.black87,
                          fontWeight: _selectedIndex == 1 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTournamentsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_tournaments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No tournaments available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createTournament,
              child: const Text('Create Tournament'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _tournaments.length,
        itemBuilder: (context, index) {
          final tournament = _tournaments[index];
          return _TournamentCard(tournament: tournament);
        },
      ),
    );
  }
  
  Widget _buildLeaguesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_leagues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No leagues available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createLeague,
              child: const Text('Create League'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _leagues.length,
        itemBuilder: (context, index) {
          final league = _leagues[index];
          return _LeagueCard(league: league);
        },
      ),
    );
  }
  
  Widget _TournamentCard({required Tournament tournament}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tournament.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (tournament.isFeatured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Featured',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTournamentStatusColor(tournament.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tournament.statusDisplay,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tournament.description ?? 'No description available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.gamepad, size: 16, color: Colors.grey[600]),
                Text(
                  tournament.gameType,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                Text(
                  '${tournament.currentParticipants}/${tournament.maxParticipants}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.trending_up, size: 16, color: Colors.grey[600]),
                Text(
                  'ELO: ${tournament.eloMin}-${tournament.eloMax}',
                  style: [
                    fontSize: 14,
                    color: Colors.grey[600],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                Text(
                  'Registration ends: ${_formatDate(tournament.registrationEnd)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                Text(
                  'Prize: ${tournament.prizePool}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.format_list_numbered, size: 16, color: Colors.grey[600]),
                Text(
                  'Format: ${tournament.formatDisplay}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.category, size: 16, color: Colors.grey[600]),
                Text(
                  'Type: ${tournament.tournamentTypeDisplay}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showTournamentDetails(tournament),
                    child: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (tournament.isRegistrationOpen)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await _tournamentService.registerForTournament(tournament.id);
                          if (result.success) {
                            _showSuccessMessage('Successfully registered for tournament!');
                            _loadData();
                          } else {
                            _showErrorMessage(result.message);
                          }
                        },
                        child: const Text('Register'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _LeagueCard({required League league}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  league.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: league.isActive ? Colors.green[100] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    league.statusDisplay,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: league.isActive ? Colors.green[800] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              league.description ?? 'No description available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.leaderboard, size: 16, color: Colors.grey[600]),
                Text(
                  league.gameType,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                Text(
                  '${league.currentPlayers}/${league.maxPlayers}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.trending_up, size: 16, color: Colors.grey[600]),
                Text(
                  'ELO: ${league.minElo}-${league.maxElo}',
                  style: [
                    fontSize: 14,
                    color: Colors.grey[600],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                Text(
                  'Season ${league.seasonNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.category, size: 16, color: Colors.grey[600]),
                Text(
                  league.leagueTypeDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    color: league.isSeasonal ? Colors.blue[600] : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.grade, size: 16, color: Colors.grey[600]),
                Text(
                  league.divisionDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getDivisionColor(league.division),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                Text(
                  'Season ends: ${_formatDate(league.seasonEnd)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (league.hasPromotion || league.hasRelegation) ...[
                  const Spacer(),
                  if (league.hasPromotion)
                    Icon(Icons.arrow_upward, size: 16, color: Colors.green[600]),
                  if (league.hasRelegation)
                    Icon(Icons.arrow_downward, size: 16, color: Colors.red[600]),
                  Text(
                    'Promotion: ${league.promotionCount} | Relegation: ${league.relegationCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showLeagueDetails(league),
                    child: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (league.isActive)
                  Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await _leagueService.joinLeague(league.id);
                        if (result.success) {
                          _showSuccessMessage('Successfully joined league!');
                          _loadData();
                        } else {
                          _showErrorMessage(result.message);
                        }
                      },
                      child: const Text('Join League'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getTournamentStatusColor(String status) {
    switch (status) {
      case 'registration':
        return Colors.green;
      case 'active':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Color _getDivisionColor(String division) {
    switch (division) {
      case 'bronze':
        return Colors.brown[600];
      case 'silver':
        return Colors.grey[600];
      case 'gold':
        return Colors.yellow[600];
      case 'platinum':
        return Colors.purple[600];
      case 'diamond':
        return Colors.purple[900];
      case 'main':
        return Colors.blue[600];
      default:
        return Colors.grey[600];
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Écran de détails d'un tournoi
class TournamentDetailScreen extends StatefulWidget {
  final Tournament tournament;
  
  const TournamentDetailScreen({super.key, required this.tournament});
  
  @override
  State<TournamentDetailScreenState> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final TournamentService _tournamentService = TournamentService.instance;
  
  bool _isLoading = false;
  List<TournamentStanding> _standings = [];
  List<TournamentParticipant> _participants = [];
  List<TournamentMatch> _matches = [];
  List<TournamentReward> _rewards = [];
  
  @override
  void initState() {
    super.initState();
    _loadTournamentData();
  }
  
  Future<void> _loadTournamentData() async {
    setState(() => _isLoading = true);
    
    final standings = await _tournamentService.getTournamentStandings(widget.tournament.id);
    final participants = await _tournamentService.getTournamentParticipants(widget.tournament.id);
    final matches = await _tournamentService.getTournamentMatches(widget.tournament.id);
    final rewards = await _tournamentService.getTournamentRewards(widget.tournament.id);
    
    setState(() {
      _standings = standings;
      _participants = participants;
      _matches = matches;
      _rewards = rewards;
      _isLoading = false;
    });
  }
  
  Future<void> _registerForTournament() async {
    final result = await _tournamentService.registerForTournament(widget.tournament.id);
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.green,
        ),
      );
      _loadTournamentData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournament.name),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        actions: [
          if (widget.tournament.isRegistrationOpen)
            IconButton(
              icon: const Icon(Icons.how_to_reg),
              onPressed: _registerForTournament,
              tooltip: 'Register for Tournament',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTournamentInfo(),
                  const SizedBox(height: 24),
                  _buildStandingsSection(),
                  const SizedBox(height: 24),
                  _buildParticipantsSection(),
                  const SizedBox(height: 24),
                  _buildMatchesSection(),
                  const SizedBox(height: 24),
                  _buildRewardsSection(),
                ],
              ),
            ),
          ),
    );
  }
  
  Widget _buildTournamentInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tournament Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Game Type', widget.tournament.gameType),
            _buildInfoRow('Format', widget.tournament.formatDisplay),
            _buildInfoRow('Type', widget.tournament.tournamentTypeDisplay),
            _buildInfoRow('Status', widget.tournament.statusDisplay),
            _buildInfoRow('Participants', '${widget.tournament.currentParticipants}/${widget.tournament.maxParticipants}'),
            _buildInfoRow('Registration', _formatDate(widget.tournament.registrationEnd)),
            _buildInfoRow('Start Date', _formatDate(widget.tournament.startDate)),
            _buildInfoRow('End Date', _formatDate(widget.tournament.endDate)),
            _buildInfoRow('Prize Pool', '\$${widget.tournament.prizePool}'),
            _buildInfoRow('Entry Fee', '${widget.tournament.entryFee}'),
            _buildInfoRow('ELO Range', '${widget.tournament.eloMin}-${widget.tournament.eloMax}'),
            if (widget.tournament.description.isNotEmpty)
              _buildInfoRow('Description', widget.tournament.description),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
            style: TextStyle(
              color: Colors.black54,
            ),
          ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStandingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tournament Standings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (_standings.isEmpty)
              const Text(
                'No standings available yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              )
            else
              ..._standings.map((standing) => _StandingRow(standing: standing)),
          ],
        ),
      ),
    );
  }
  
  Widget _StandingRow(TournamentStanding standing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${standing.rankPosition}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  standing.participantName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Points: ${standing.points} | Matches: ${standing.matchesPlayed}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'W: ${standing.matchesWon} | L: ${standing.matchesLost} | D: ${standing.matchesDrawn}',
                  style: [
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                Text(
                  'Win Rate: ${standing.winRate.toStringAsFixed(1)}%',
                  style: [
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ELO: ${standing.eloRatingBefore}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (standing.eloRatingAfter != null)
                Text(
                  '→ ${standing.eloRatingAfter}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getEloChangeColor(standing.eloRatingBefore, standing.eloRatingAfter),
                  ),
                ),
              if (standing.prizeWon > 0)
                Text(
                  'Prize: ${standing.prizeWon}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Color _getEloChangeColor(int before, int after) {
    if (after > before) return Colors.green;
    if (after < before) return Colors.red;
    return Colors.grey;
  }
  
  Widget _buildParticipantsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
            'Participants (${_participants.length})',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            ),
            const SizedBox(height: 16),
            if (_participants.isEmpty)
              const Text(
                'No participants yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              )
            else
              ..._participants.map((participant) => _ParticipantRow(participant: participant)),
          ],
        ),
      ),
    );
  }
  
  Widget _ParticipantRow(TournamentParticipant participant) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${participant.seedNumber}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player ${participant.userId.substring(0, 8)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Status: ${participant.statusDisplay}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getParticipantStatusColor(participant.status),
                  ),
                ),
                Text(
                  'Matches: ${participant.matchesPlayed} | W: ${participant.matchesWon} | L: ${participant.matchesLost}',
                  style: [
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                Text(
                  'Points: ${participant.points}',
                  style: [
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ELO: ${participant.eloRatingBefore}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (participant.eloRatingAfter != null)
                Text(
                  '→ ${participant.eloRatingAfter}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getEloChangeColor(participant.eloRatingBefore, participant.eloRatingAfter),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Color _getParticipantStatusColor(String status) {
    switch (status) {
      case 'registered':
        return Colors.blue;
      case 'active':
        return Colors.green;
      case 'eliminated':
        return Colors.red;
      case 'winner':
        return Colors.amber;
      case 'withdrawn':
        return Colors.orange;
      case 'disqualified':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildMatchesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Matches (${_matches.length})',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            ),
            const SizedBox(height: 16),
            if (_matches.isEmpty)
              const Text(
                'No matches scheduled yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              )
            else
              ..._matches.map((match) => _MatchRow(match: match)),
          ],
        ),
      ),
    );
  }
  
  Widget _MatchRow(TournamentMatch match) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _getMatchStatusColor(match.status)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Round ${match.roundNumber} - Match ${match.matchNumber}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${match.statusDisplay}',
                style: TextStyle(
                  fontSize: 12,
                  color: _getMatchStatusColor(match.status),
                ),
              if (match.scheduledAt != null)
                Text(
                  'Scheduled: ${_formatDate(match.scheduledAt)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              if (match.isCompleted)
                Text(
                  'Completed: ${_formatDate(match.completedAt)}',
                  style: [
                    TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (match.participant1Score > 0 || match.participant2Score > 0)
                Row(
                  children: [
                    Text(
                      'Score: ${match.participant1Score} - ${match.participant2Score}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    if (match.winnerId != null)
                      Text(
                        'Winner: Player ${match.winnerId.substring(0, 8)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getMatchStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildRewardsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prizes (${_rewards.length})',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            ),
            const SizedBox(height: 16),
            if (_rewards.isEmpty)
              const Text(
                'No prizes available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              )
            else
              ..._rewards.map((reward) => _RewardRow(reward: reward)),
          ],
        ),
      ),
    );
  }
  
  Widget _RewardRow(TournamentReward reward) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRewardTypeColor(reward.rewardType),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  reward.rewardTypeDisplay,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                reward.rankDisplay,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (reward.rewardValue > 0)
                Text(
                  'Reward: ${reward.rewardValue}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[600],
                  ),
                ),
              if (reward.rewardName.isNotEmpty)
                Text(
                  reward.rewardName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getRewardTypeColor(String rewardType) {
    switch (rewardType) {
      case 'cash':
        return Colors.green;
      case 'points':
        return Colors.blue;
      case 'badge':
        return Colors.purple;
      case 'item':
        return Colors.orange;
      case 'promotion':
        return Colors.teal;
      case 'relegation':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Écran de détails d'une ligue
class LeagueDetailScreen extends StatefulWidget {
  final League league;
  
  const LeagueDetailScreen({super.key, required this.league});
  
  @override
  State<LeagueDetailScreenState> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<LeagueDetailScreen> {
  final LeagueService _leagueService = LeagueService.instance;
  
  bool _isLoading = false;
  List<LeagueStanding> _standings = [];
  List<LeagueParticipant> _participants = [];
  List<LeagueMatch> _matches = [];
  List<LeagueReward> _rewards = [];
  
  @override
  void initState() {
    super.initState();
    _loadLeagueData();
  }
  
  Future<void> _loadLeagueData() async {
    setState(() => _isLoading = true);
    
    final standings = await _leagueService.getLeagueStandings(widget.league.id);
    final participants = await _leagueService.getLeagueParticipants(widget.league.id);
    final matches = await _leagueService.getLeagueMatches(widget.league.id);
    final rewards = await _leagueService.getLeagueRewards(widget.league.id);
    
    setState(() {
      _standings = standings;
      _participants = participants;
      _matches = matches;
      _rewards = rewards;
      _isLoading = false;
    });
  }
  
  Future<void> _joinLeague() async {
    final result = await _leagueService.joinLeague(widget.league.id);
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.green,
        ),
      );
      _loadLeagueData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _leaveLeague() async {
    final result = await _leagueService.leaveLeague(widget.league.id);
    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: 'Left league successfully',
          backgroundColor: Colors.green,
        ),
      );
      _loadLeagueData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: 'Failed to leave league',
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.league.name),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        actions: [
          if (widget.league.isActive)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _leaveLeague,
              tooltip: 'Leave League',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLeagueInfo(),
                  const SizedBox(height: 24),
                  _buildStandingsSection(),
                  const SizedBox(height: 24),
                  _buildParticipantsSection(),
                  const SizedBox(height: 24),
                  _buildMatchesSection(),
                  const SizedBox(height: 24),
                  _buildRewardsSection(),
                ],
              ),
            ),
          ),
    );
  }
  
  Widget _buildLeagueInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'League Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Game Type', widget.league.gameType),
            _buildInfoRow('League Type', widget.league.leagueTypeDisplay),
            _buildInfoRow('Division', widget.league.divisionDisplay),
            _buildInfoRow('Season', widget.seasonDisplay),
            _buildInfoRow('Status', widget.league.statusDisplay),
            _buildInfoRow('Players', '${widget.league.currentPlayers}/${widget.league.maxPlayers}'),
            _buildInfoRow('Season Start', _formatDate(widget.league.seasonStart)),
            _buildInfoRow('Season End', _formatDate(widget.league.seasonEnd)),
            _buildInfoRow('Min ELO', '${widget.league.minElo}'),
            _buildInfoRow('Max ELO', '${widget.league.maxElo}'),
            if (widget.league.description.isNotEmpty)
              _buildInfoRow('Description', widget.league.description),
            if (widget.hasPromotion || widget.hasRelegation)
              _buildInfoRow('Promotion/Relegation', '${widget.promotionCount} / ${widget.relegationCount}'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStandingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'League Standings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (_standings.isEmpty)
              const Text(
                'No standings available yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              )
            else
              ..._standings.map((standing) => _StandingRow(standing: standing)),
          ],
        ),
      ),
    );
  }
  
  Widget _StandingRow(LeagueStanding standing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${standing.rankPosition}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  standing.participantName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Points: ${standing.points} | Matches: ${standing.matchesPlayed}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'W: ${standing.matchesWon} | L: ${standing.matchesLost} | D: ${standing.matchesDrawn}',
                  style: [
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                Text(
                  'Win Rate: ${standing.winRate.toStringAsFixed(1)}%',
                  style: [
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ELO: ${standing.eloRating}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (standing.eloChange != 0)
                Text(
                  '→ ${standing.eloChange}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getEloChangeColor(standing.eloRating, standing.eloChange),
                  ),
                ),
              if (standing.seasonPoints > 0)
                Text(
                  'Season: ${standing.seasonPoints}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Color _getEloChangeColor(int current, int change) {
    if (change > 0) return Colors.green;
    if (change < 0) return Colors.red;
    return Colors.grey;
  }
  
  Widget _buildParticipantsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participants (${_participants.length})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (_participants.isEmpty)
              const Text(
                'No participants yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              )
            else
              ..._participants.map((participant) => _ParticipantRow(participant: participant)),
          ],
        ),
      ),
    );
  }
  
  Widget _ParticipantRow(LeagueParticipant participant) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${participant.rankPosition}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player ${participant.userId.substring(0, 8)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Status: ${participant.statusDisplay}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getParticipantStatusColor(participant.status),
                  ),
                ),
                Text(
                  'Matches: ${participant.matchesPlayed} | W: ${participant.matchesWon} | L: ${participant.matchesLost} | D: ${participant.matchesDrawn}',
                  style: [
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                Text(
                  'Points: ${participant.points}',
                  style: [
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ELO: ${participant.eloRating}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (participant.eloChange != 0)
                Text(
                  '→ ${participant.eloChange}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getEloChangeColor(participant.eloRating, participant.eloChange),
                  ),
                ),
              if (participant.currentStreak != 0)
                Text(
                  'Streak: ${participant.currentStreak}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStreakColor(participant.currentStreak),
                  ),
                ),
              if (participant.bestStreak > 0)
                Text(
                  'Best: ${participant.bestStreak}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Color _getParticipantStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'promoted':
        return Colors.teal;
      case 'relegated':
        return Colors.red;
      case 'banned':
        return Colors.red;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  Color _getStreakColor(int streak) {
    if (streak > 0) return Colors.green;
    if (streak < 0) return Colors.red;
    return Colors.grey;
  }
  
  Widget _buildMatchesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Matches (${_matches.length})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (_matches.isEmpty)
              const Text(
                'No matches yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              )
            else
              ..._matches.map((match) => _MatchRow(match: match)),
          ],
        ),
      ),
    );
  }
  
  Widget _MatchRow(LeagueMatch match) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _getMatchStatusColor(match.status)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match on ${_formatDate(match.scheduledAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              if (match.isCompleted)
                Row(
                  children: [
                    Text(
                      'Score: ${match.participant1Score} - ${match.participant2Score}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    if (match.winnerId != null)
                      Text(
                        'Winner: ${match.winnerId.substring(0, 8)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                        ),
                  ],
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Points: ${match.participant1Points} - ${match.participant2Points}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  if (match.participant1EloChange != 0 || match.participant2EloChange != 0)
                    Text(
                      'ELO: ${match.participant1EloChange > 0 ? '+' : ''}${match.participant1EloChange}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getEloChangeColor(match.participant1EloChange, match.participant2EloChange),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getMatchStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Color _getEloChangeColor(int change) {
    if (change > 0) return Colors.green;
    if (change < 0) return Colors.red;
    return Colors.grey;
  }
  
  Widget _buildRewardsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'League Rewards (${_rewards.length})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (_rewards.isEmpty)
              const Text(
                'No rewards available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              )
            else
              ..._rewards.map((reward) => _RewardRow(reward: reward)),
          ],
        ),
      ),
    );
  }
  
  Widget _RewardRow(LeagueReward reward) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRewardTypeColor(reward.rewardType),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  reward.rewardTypeDisplay,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                reward.rankDisplay,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (reward.rewardValue > 0)
                Text(
                  'Reward: ${reward.rewardValue}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[600],
                  ),
                ),
              if (reward.rewardName.isNotEmpty)
                Text(
                  reward.rewardName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getRewardTypeColor(String rewardType) {
    switch (rewardType) {
      case 'promotion':
        return Colors.teal;
      case 'relegation':
        return Colors.red;
      case 'badge':
        return Colors.purple;
      case 'points':
        return Colors.blue;
      case 'item':
        return Colors.orange;
      case 'cash':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

/// Événement compétitif
class CompetitiveEvent {
  final String id;
  final String? tournamentId;
  final String? leagueId;
  final String? matchId;
  final String? participantId;
  final String eventType;
  final Map<String, dynamic> eventData;
  final DateTime createdAt;
  
  CompetitiveEvent({
    required this.id,
    this.tournamentId,
    this.leagueId,
    this.matchId,
    this.participantId,
    required this.eventType,
    this.eventData,
    required this.createdAt,
  });
  
  factory CompetitiveEvent.fromJson(Map<String, dynamic> json) {
    return CompetitiveEvent(
      id: json['id'],
      tournamentId: json['tournament_id'],
      leagueId: json['league_id'],
      matchId: json['match_id'],
      participantId: json['participant_id'],
      eventType: json['event_type'],
      eventData: json['event_data'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  String get eventTypeDisplay {
    switch (eventType) {
      case 'tournament_created':
        return 'Tournament Created';
      case 'match_completed':
        return 'Match Completed';
      case 'player_eliminated':
        return 'Player Eliminated';
      case 'promotion':
        return 'Promotion';
      case 'relegation':
        return 'Relegation';
      case 'achievement':
        return 'Achievement';
      default:
        return eventType;
    }
  }
}
