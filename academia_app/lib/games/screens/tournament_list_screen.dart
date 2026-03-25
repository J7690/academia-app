import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tournament_provider.dart';
import '../widgets/tournament_bracket_widget.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({Key? key}) : super(key: key);

  @override
  _TournamentListScreenState createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TournamentProvider>(context, listen: false).loadAvailableTournaments();
      Provider.of<TournamentProvider>(context, listen: false).loadAvailableLeagues();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tournaments & Leagues'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Tournaments', icon: Icon(Icons.emoji_events)),
            Tab(text: 'Leagues', icon: Icon(Icons.leaderboard)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showCreateTournamentDialog(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTournamentsTab(),
          _buildLeaguesTab(),
        ],
      ),
    );
  }

  Widget _buildTournamentsTab() {
    return Consumer<TournamentProvider>(
      builder: (context, provider, child) {
        if (provider.availableTournaments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No tournaments available',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Create a tournament to get started!',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _showCreateTournamentDialog(),
                  child: Text('Create Tournament'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await provider.loadAvailableTournaments();
          },
          child: ListView.builder(
            itemCount: provider.availableTournaments.length,
            itemBuilder: (context, index) {
              final tournament = provider.availableTournaments[index];
              return TournamentCard(
                tournament: tournament,
                onTap: () => _showTournamentDetails(tournament),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLeaguesTab() {
    return Consumer<TournamentProvider>(
      builder: (context, provider, child) {
        if (provider.availableLeagues.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.leaderboard_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No leagues available',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Join a league to compete regularly!',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await provider.loadAvailableLeagues();
          },
          child: ListView.builder(
            itemCount: provider.availableLeagues.length,
            itemBuilder: (context, index) {
              final league = provider.availableLeagues[index];
              return LeagueCard(
                league: league,
                onTap: () => _showLeagueDetails(league),
              );
            },
          ),
        );
      },
    );
  }

  void _showCreateTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateTournamentDialog(),
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
}

class TournamentDetailScreen extends StatefulWidget {
  final Tournament tournament;
  
  const TournamentDetailScreen({required this.tournament});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournament.name),
        actions: [
          Consumer<TournamentProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: Icon(Icons.edit),
                onPressed: () => _showEditDialog(context, provider),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.tournament.description,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            _buildInfoCard(),
            SizedBox(height: 16),
            _buildParticipantsCard(),
            SizedBox(height: 16),
            _buildBracketCard(),
            SizedBox(height: 16),
            _buildActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tournament Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _buildInfoRow('Game Type', widget.tournament.gameType),
            _buildInfoRow('Tournament Type', widget.tournament.tournamentType),
            _buildInfoRow('Format', widget.tournament.format),
            _buildInfoRow('Max Participants', '${widget.tournament.currentParticipants}/${widget.tournament.maxParticipants}'),
            _buildInfoRow('Status', widget.tournament.status.toUpperCase()),
            _buildInfoRow('Registration', '${_formatDate(widget.tournament.registrationStart)} - ${_formatDate(widget.tournament.registrationEnd)}'),
            _buildInfoRow('Tournament', '${_formatDate(widget.tournament.startDate)} - ${_formatDate(widget.tournament.endDate)}'),
            if (widget.tournament.prizePool > 0) _buildInfoRow('Prize Pool', '${widget.tournament.prizePool}'),
            if (widget.tournament.entryFee > 0) _buildInfoRow('Entry Fee', '${widget.tournament.entryFee}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildParticipantsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Participants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Consumer<TournamentProvider>(
              builder: (context, provider, child) {
                return FutureBuilder(
                  future: _loadParticipants(widget.tournament.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }
                    
                    final participants = snapshot.data ?? [];
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        final participant = participants[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(participant['name'][0].toUpperCase()),
                          ),
                          title: Text(participant['name']),
                          subtitle: Text('Seed: ${participant['seed_number']}'),
                          trailing: Text(participant['status']),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBracketCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tournament Bracket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Consumer<TournamentProvider>(
              builder: (context, provider, child) {
                return FutureBuilder(
                  future: _loadMatches(widget.tournament.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }
                    
                    final matches = snapshot.data ?? [];
                    if (matches.isEmpty) {
                      return Text('No matches available yet');
                    }
                    
                    return TournamentBracketWidget(matches: matches);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Consumer<TournamentProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    if (widget.tournament.status == 'registration')
                      ElevatedButton(
                        onPressed: () => _registerForTournament(provider),
                        child: Text('Register'),
                      ),
                    if (widget.tournament.status == 'active')
                      ElevatedButton(
                        onPressed: () => _viewMyMatches(provider),
                        child: Text('My Matches'),
                      ),
                    SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _viewStandings(provider),
                      child: Text('View Standings'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, TournamentProvider provider) {
    // TODO: Implement edit dialog
  }

  void _registerForTournament(TournamentProvider provider) {
    provider.registerTournament(widget.tournament.id).then((success) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully registered for tournament!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to register for tournament')),
        );
      }
    });
  }

  void _viewMyMatches(TournamentProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyMatchesScreen(tournamentId: widget.tournament.id),
      ),
    );
  }

  void _viewStandings(TournamentProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentStandingsScreen(tournamentId: widget.tournament.id),
      ),
    );
  }

  Future<List<dynamic>> _loadParticipants(String tournamentId) async {
    // TODO: Implement participants loading
    return [];
  }

  Future<List<TournamentMatch>> _loadMatches(String tournamentId) async {
    // TODO: Implement matches loading
    return [];
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class LeagueDetailScreen extends StatelessWidget {
  final League league;
  
  const LeagueDetailScreen({required this.league});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(league.name),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              league.description,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            _buildInfoCard(),
            SizedBox(height: 16),
            _buildStandingsCard(),
            SizedBox(height: 16),
            _buildActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('League Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _buildInfoRow('Game Type', league.gameType),
            _buildInfoRow('Division', league.division),
            _buildInfoRow('Season', 'Season ${league.seasonNumber}'),
            _buildInfoRow('Status', league.status.toUpperCase()),
            _buildInfoRow('Start Date', _formatDate(league.startDate)),
            _buildInfoRow('End Date', _formatDate(league.endDate)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildStandingsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('League Standings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Standings will be available here'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Consumer<TournamentProvider>(
              builder: (context, provider, child) {
                return ElevatedButton(
                  onPressed: () => provider.joinLeague(league.id),
                  child: Text('Join League'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class MyMatchesScreen extends StatelessWidget {
  final String tournamentId;
  
  const MyMatchesScreen({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Matches'),
      ),
      body: Consumer<TournamentProvider>(
        builder: (context, provider, child) {
          if (provider.myMatches.isEmpty) {
            return Center(
              child: Text('No matches available'),
            );
          }

          return ListView.builder(
            itemCount: provider.myMatches.length,
            itemBuilder: (context, index) {
              final match = provider.myMatches[index];
              return MatchCard(match: match);
            },
          );
        },
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final TournamentMatch match;
  
  const MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Round ${match.round} - Match ${match.matchNumber}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Player 1: ${match.player1Id ?? 'TBD'}'),
                Text('Player 2: ${match.player2Id ?? 'TBD'}'),
              ],
            ),
            SizedBox(height: 8),
            Text('Status: ${match.status}'),
            if (match.status == 'completed') ...[
              SizedBox(height: 4),
              Text('Score: ${match.player1Score} - ${match.player2Score}'),
              if (match.winnerId != null)
                Text('Winner: ${match.winnerId}'),
            ],
          ],
        ),
      ),
    );
  }
}

class TournamentStandingsScreen extends StatelessWidget {
  final String tournamentId;
  
  const TournamentStandingsScreen({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tournament Standings'),
      ),
      body: Center(
        child: Text('Standings will be available here'),
      ),
    );
  }
}
