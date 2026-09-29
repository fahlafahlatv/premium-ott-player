import 'dart:async';
import 'dart:convert';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

void main() => runApp(const TivioApp());

class TivioApp extends StatelessWidget {
  const TivioApp({super.key, this.playlistUrl});
  final String? playlistUrl;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TIVIO',
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: TivioColors.background,
          colorScheme: const ColorScheme.dark(primary: TivioColors.cyan),
          textTheme: ThemeData.dark(useMaterial3: true).textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ),
        home: PremiumOttPlayerScreen(playlistUrl: playlistUrl),
      );
}

class TivioColors {
  static const background = Color(0xff040714);
  static const panel = Color(0xff090e22);
  static const panelAlt = Color(0xff101a32);
  static const cyan = Color(0xff00e5ff);
  static const muted = Color(0xff7f8ea6);
}

class IptvChannel {
  const IptvChannel({
    required this.id,
    required this.name,
    required this.logo,
    required this.category,
    required this.program,
    required this.details,
    required this.progress,
    required this.streamUrl,
    this.isRadio = false,
  });

  final String id;
  final String name;
  final String logo;
  final String category;
  final String program;
  final String details;
  final double progress;
  final String streamUrl;
  final bool isRadio;
}

class PremiumOttPlayerScreen extends StatefulWidget {
  const PremiumOttPlayerScreen({super.key, this.playlistUrl});
  final String? playlistUrl;

  @override
  State<PremiumOttPlayerScreen> createState() => _PremiumOttPlayerScreenState();
}

class _PremiumOttPlayerScreenState extends State<PremiumOttPlayerScreen> {
  final List<IptvChannel> _fallbackChannels = const [
    IptvChannel(
      id: 'tivio-one',
      name: 'TIVIO One',
      logo: 'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=200&q=80',
      category: 'Featured',
      program: 'The Morning Feed',
      details: 'Live broadcast • HD',
      progress: 0.42,
      streamUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    ),
    IptvChannel(
      id: 'tivio-sport',
      name: 'TIVIO Sport',
      logo: 'https://images.unsplash.com/photo-1547347298-4074fc3086f0?auto=format&fit=crop&w=200&q=80',
      category: 'Sports',
      program: 'Championship Night',
      details: 'Live arena • 4K',
      progress: 0.78,
      streamUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
    ),
    IptvChannel(
      id: 'tivio-cinema',
      name: 'TIVIO Cinema',
      logo: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=200&q=80',
      category: 'Movies',
      program: 'Neon Horizon',
      details: 'Premiere • Dolby',
      progress: 0.65,
      streamUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    ),
    IptvChannel(
      id: 'tivio-music',
      name: 'TIVIO Beats',
      logo: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=200&q=80',
      category: 'Music',
      program: 'Live Session',
      details: 'Audio stream • Studio',
      progress: 0.51,
      streamUrl: 'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      isRadio: true,
    ),
  ];

  List<IptvChannel> _channels = [];
  Set<String> _favorites = {};
  Timer? _reconnectTimer;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool _loading = true;
  bool _reconnecting = false;
  bool _showSettings = false;
  bool _sidebarVisible = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String? _currentChannelId;
  String? _loadError;

  List<String> get _categories {
    final names = <String>{'All'};
    for (final channel in _channels) {
      names.add(channel.category);
    }
    return names.toList()..sort();
  }

  IptvChannel? get _currentChannel => _channels.isEmpty ? null : _channels.firstWhere(
        (channel) => channel.id == _currentChannelId,
        orElse: () => _channels.first,
      );

  List<IptvChannel> get _filteredChannels {
    final base = _selectedCategory == 'Favorites'
        ? _channels.where((channel) => _favorites.contains(channel.id))
        : _channels.where((channel) {
            final categoryOk = _selectedCategory == 'All' || channel.category == _selectedCategory;
            final queryOk = _searchQuery.trim().isEmpty ||
                channel.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                channel.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                channel.program.toLowerCase().contains(_searchQuery.toLowerCase());
            return categoryOk && queryOk;
          });

    return base.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final String body;
      if (widget.playlistUrl == null || widget.playlistUrl!.trim().isEmpty) {
        body = _buildDemoPlaylist();
      } else {
        final response = await http.get(Uri.parse(widget.playlistUrl!)).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw Exception('Playlist request failed with status ${response.statusCode}.');
        }
        body = response.body;
      }

      final parsed = _parseM3u(body);
      if (parsed.isEmpty) {
        throw Exception('No playable channels were found in the playlist.');
      }

      setState(() {
        _channels = parsed;
        _loading = false;
      });

      if (_channels.isNotEmpty) {
        await _tuneInto(_channels.first);
      }
    } catch (error) {
      debugPrint('Playlist load failed: $error');
      setState(() {
        _channels = _fallbackChannels;
        _loadError = error.toString();
        _loading = false;
      });

      if (_channels.isNotEmpty) {
        await _tuneInto(_channels.first);
      }
    }
  }

  String _buildDemoPlaylist() {
    final channels = [
      '#EXTM3U',
      '#EXTINF:-1 group-title="Featured" tvg-logo="https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=96&q=80",TIVIO One',
      'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
      '#EXTINF:-1 group-title="Sports" tvg-logo="https://images.unsplash.com/photo-1547347298-4074fc3086f0?auto=format&fit=crop&w=96&q=80",TIVIO Sport',
      'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
      '#EXTINF:-1 group-title="Movies" tvg-logo="https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=96&q=80",TIVIO Cinema',
      'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      '#EXTINF:-1 group-title="Music" tvg-logo="https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=96&q=80",TIVIO Beats',
      'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ];
    return channels.join('\n');
  }

  List<IptvChannel> _parseM3u(String body) {
    final lines = const LineSplitter().convert(body).map((line) => line.trim()).toList();
    final result = <IptvChannel>[];

    String currentGroup = 'General';
    String currentLogo = '';
    String currentName = 'TIVIO Channel';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        continue;
      }

      if (line.startsWith('#EXTINF:')) {
        final groupMatch = RegExp(r'group-title="([^"]+)"').firstMatch(line);
        if (groupMatch != null) {
          currentGroup = groupMatch.group(1) ?? 'General';
        }

        final logoMatch = RegExp(r'tvg-logo="([^"]+)"').firstMatch(line);
        if (logoMatch != null) {
          currentLogo = logoMatch.group(1) ?? '';
        }

        final commaIndex = line.lastIndexOf(',');
        if (commaIndex != -1 && commaIndex < line.length - 1) {
          currentName = line.substring(commaIndex + 1).trim();
        }
        continue;
      }

      if (line.startsWith('#')) {
        continue;
      }

      final parsedUrl = Uri.tryParse(line);
      if (parsedUrl == null || !parsedUrl.hasScheme) {
        continue;
      }

      result.add(
        IptvChannel(
          id: '${currentName}_${result.length}_${line.hashCode}',
          name: currentName,
          logo: currentLogo.isNotEmpty ? currentLogo : 'https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?auto=format&fit=crop&w=200&q=80',
          category: currentGroup,
          program: 'Live Curated Broadcast',
          details: 'TIVIO • Secure stream',
          progress: 0.48,
          streamUrl: line,
          isRadio: currentGroup.toLowerCase().contains('radio'),
        ),
      );

      currentLogo = '';
    }

    return result;
  }

  Future<void> _tuneInto(IptvChannel channel) async {
    if (_currentChannelId == channel.id && _chewieController != null) {
      return;
    }

    _reconnectTimer?.cancel();
    setState(() {
      _currentChannelId = channel.id;
      _reconnecting = false;
    });

    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(channel.streamUrl));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      _videoController = controller;
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        isLive: true,
        allowFullScreen: false,
        showControls: true,
        aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: TivioColors.cyan,
          handleColor: TivioColors.cyan,
          bufferedColor: TivioColors.cyan.withOpacity(0.35),
          backgroundColor: Colors.white24,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator(color: TivioColors.cyan)),
        ),
        errorBuilder: (context, errorMessage) {
          _scheduleReconnect(channel);
          return _errorRecoveryCard(errorMessage);
        },
      );

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Tune failed: $error');
      _scheduleReconnect(channel);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _scheduleReconnect(IptvChannel channel) {
    if (_reconnecting) {
      return;
    }

    setState(() {
      _reconnecting = true;
    });

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_retrySeconds > 1) {
        setState(() => _retrySeconds--);
      } else {
        timer.cancel();
        setState(() => _reconnecting = false);
        _tuneInto(channel);
      }
    });
  }

  int _retrySeconds = 5;

  Widget _errorRecoveryCard(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 42, color: TivioColors.cyan),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Retrying in $_retrySeconds seconds',
              style: const TextStyle(color: TivioColors.cyan, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFavorite(IptvChannel channel) {
    setState(() {
      if (_favorites.contains(channel.id)) {
        _favorites.remove(channel.id);
      } else {
        _favorites.add(channel.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TivioColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 960;
            return Row(
              children: [
                if (!compact && _sidebarVisible) _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(compact),
                      Expanded(
                        child: _showSettings ? _buildSettingsScreen() : _buildMainContent(compact),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: TivioColors.panel,
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TIVIO',
              style: TextStyle(
                color: TivioColors.cyan,
                fontSize: 26,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'BROWSE',
              style: TextStyle(
                color: TivioColors.muted,
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ..._categories.map((category) => _categoryTile(category)),
            const Spacer(),
            _categoryTile('Favorites'),
            const SizedBox(height: 12),
            const Text(
              'v1.0 • STREAM READY',
              style: TextStyle(color: TivioColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTile(String category) {
    final isSelected = category == 'Favorites' ? _selectedCategory == 'Favorites' : category == _selectedCategory;
    final isFavorites = category == 'Favorites';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        selected: isSelected,
        selectedTileColor: TivioColors.cyan.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          isFavorites ? Icons.favorite_rounded : Icons.grid_view_rounded,
          size: 18,
          color: isSelected ? TivioColors.cyan : TivioColors.muted,
        ),
        title: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.white : TivioColors.muted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: () => setState(() {
          _selectedCategory = category;
        }),
      ),
    );
  }

  Widget _buildTopBar(bool compact) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: TivioColors.panel,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (compact)
            IconButton(
              onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
              icon: const Icon(Icons.menu_rounded),
            ),
          const Text(
            'LIVE TV',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: compact ? 180 : 260,
            height: 40,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search channels',
                hintStyle: const TextStyle(color: TivioColors.muted),
                filled: true,
                fillColor: TivioColors.background,
                prefixIcon: const Icon(Icons.search_rounded, color: TivioColors.muted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => setState(() => _showSettings = !_showSettings),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool compact) {
    final list = _filteredChannels;
    final current = _currentChannel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlayerPanel(),
          if (current != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${current.category} • ${current.program}',
                        style: const TextStyle(color: TivioColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _toggleFavorite(current),
                  icon: Icon(
                    _favorites.contains(current.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: TivioColors.cyan,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'CHANNELS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
              const Spacer(),
              Text(
                '${list.length} available',
                style: const TextStyle(color: TivioColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: compact ? 2 : 4,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: compact ? 1.25 : 1.4,
            ),
            itemBuilder: (context, index) {
              final channel = list[index];
              final selected = channel.id == _currentChannelId;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _tuneInto(channel),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: selected ? TivioColors.cyan.withOpacity(0.12) : TivioColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? TivioColors.cyan : Colors.white10,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: TivioColors.panelAlt,
                            backgroundImage: NetworkImage(channel.logo),
                          ),
                          const Spacer(),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _toggleFavorite(channel),
                            icon: Icon(
                              _favorites.contains(channel.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 18,
                              color: TivioColors.cyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        channel.category,
                        style: const TextStyle(color: TivioColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: channel.progress,
                        minHeight: 4,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(TivioColors.cyan),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SETTINGS',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 20),
          _settingsTile('Playlist source', widget.playlistUrl ?? 'Built-in demo playlist'),
          _settingsTile('Loaded channels', '${_channels.length}'),
          _settingsTile('Favorites', '${_favorites.length} saved'),
          _settingsTile('Playback', 'Auto play enabled • Live mode'),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadPlaylist,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reload playlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TivioColors.cyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.45)),
              ),
              child: Text(
                'Load status: $_loadError',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _settingsTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TivioColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: TivioColors.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: TivioColors.muted),
        ],
      ),
    );
  }

  Widget _buildPlayerPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _chewieController != null
              ? Chewie(controller: _chewieController!)
              : Container(
                  color: Colors.black,
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator(color: TivioColors.cyan)
                        : _reconnecting
                            ? _errorRecoveryCard('Connection lost')
                            : const Icon(Icons.tv_rounded, size: 54, color: TivioColors.cyan),
                  ),
                ),
        ),
      ),
    );
  }
}
