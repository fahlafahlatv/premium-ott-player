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
        ),
        home: PremiumOttPlayerScreen(playlistUrl: playlistUrl),
      );
}

class TivioColors {
  static const background = Color(0xff040714);
  static const panel = Color(0xff090e22);
  static const panel2 = Color(0xff111936);
  static const cyan = Color(0xff00e5ff);
  static const muted = Color(0xff8290ad);
}

class IptvChannel {
  const IptvChannel({required this.id, required this.name, required this.logo, required this.category, required this.program, required this.details, required this.progress, required this.streamUrl, this.isRadio = false});
  final String id, name, logo, category, program, details, streamUrl;
  final double progress;
  final bool isRadio;
}

class PremiumOttPlayerScreen extends StatefulWidget {
  const PremiumOttPlayerScreen({super.key, this.playlistUrl});
  final String? playlistUrl;

  @override
  State<PremiumOttPlayerScreen> createState() => _PremiumOttPlayerScreenState();
}

class _PremiumOttPlayerScreenState extends State<PremiumOttPlayerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  Timer? _retryTimer;
  List<IptvChannel> channels = [];
  Set<String> favorites = {};
  String category = 'All';
  String query = '';
  String? currentId;
  bool loading = true, reconnecting = false, settings = false, sidebarOpen = true;
  int retrySeconds = 5;
  Object? loadError;

  final categories = <String>['All'];
  static const demoPlaylist = 'https://storage.googleapis.com/coverr-main/mp4/Mt_Baker.mp4';

  IptvChannel? get current => channels.where((c) => c.id == currentId).firstOrNull;
  List<IptvChannel> get visibleChannels => channels.where((c) {
        final categoryMatch = category == 'All' || c.category == category;
        final queryMatch = query.isEmpty || c.name.toLowerCase().contains(query.toLowerCase()) || c.category.toLowerCase().contains(query.toLowerCase());
        return categoryMatch && queryMatch;
      }).toList();

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylist() async {
    setState(() { loading = true; loadError = null; });
    try {
      final source = widget.playlistUrl;
      String body;
      if (source == null || source.isEmpty) {
        body = '#EXTM3U\n#EXTINF:-1 group-title="Demo",TIVIO One\n$demoPlaylist\n#EXTINF:-1 group-title="Demo",TIVIO Cinema\n$demoPlaylist';
      } else {
        final response = await http.get(Uri.parse(source)).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) throw Exception('Playlist returned ${response.statusCode}');
        body = response.body;
      }
      final parsed = _parseM3u(body);
      if (parsed.isEmpty) throw Exception('No playable channels found');
      setState(() { channels = parsed; categories..clear()..addAll({'All', ...parsed.map((e) => e.category)}); loading = false; });
      await _tune(parsed.first);
    } catch (e) {
      setState(() { loadError = e; channels = _demoChannels; categories..clear()..addAll({'All', ..._demoChannels.map((e) => e.category)}); loading = false; });
      if (channels.isNotEmpty) await _tune(channels.first);
    }
  }

  List<IptvChannel> _parseM3u(String text) {
    final lines = const LineSplitter().convert(text).map((e) => e.trim()).toList();
    final result = <IptvChannel>[];
    String name = 'TIVIO Channel', group = 'General', logo = '';
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('#EXTINF:')) {
        group = RegExp(r'group-title="([^"]*)"').firstMatch(line)?.group(1) ?? 'General';
        logo = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line)?.group(1) ?? '';
        final comma = line.lastIndexOf(',');
        name = comma >= 0 ? line.substring(comma + 1).trim() : name;
      } else if (line.isNotEmpty && !line.startsWith('#') && Uri.tryParse(line)?.hasScheme == true) {
        result.add(IptvChannel(id: '${name}_${result.length}', name: name, logo: logo, category: group, program: 'Live now', details: 'TIVIO • Live broadcast', progress: .45, streamUrl: line, isRadio: group.toLowerCase().contains('radio')));
      }
    }
    return result;
  }

  Future<void> _tune(IptvChannel channel) async {
    if (currentId == channel.id && _chewie != null) return;
    _retryTimer?.cancel();
    setState(() { currentId = channel.id; reconnecting = false; });
    _chewie?.dispose();
    _video?.dispose();
    try {
      final video = VideoPlayerController.networkUrl(Uri.parse(channel.streamUrl));
      await video.initialize();
      if (!mounted) { video.dispose(); return; }
      _video = video;
      _chewie = ChewieController(videoPlayerController: video, autoPlay: true, isLive: true, allowFullScreen: false, showControls: true, errorBuilder: (_, message) => _recovery(message));
      setState(() {});
    } catch (_) {
      _startRecovery(channel);
    }
  }

  void _startRecovery(IptvChannel channel) {
    if (!mounted || reconnecting) return;
    setState(() { reconnecting = true; retrySeconds = 5; });
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (retrySeconds > 1) setState(() => retrySeconds--); else { timer.cancel(); _tune(channel); }
    });
  }

  Widget _recovery(String message) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.wifi_off_rounded, size: 42, color: TivioColors.cyan), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)), const SizedBox(height: 14), Text('Reconnecting in $retrySeconds…', style: const TextStyle(color: TivioColors.cyan))]));

  void _toggleFavorite(IptvChannel channel) => setState(() => favorites.contains(channel.id) ? favorites.remove(channel.id) : favorites.add(channel.id));

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(body: SafeArea(child: Row(children: [if (isWide && sidebarOpen) _buildSidebar(), Expanded(child: Column(children: [_buildTopBar(isWide), Expanded(child: _buildContent(isWide))]))])));
  }

  Widget _buildTopBar(bool isWide) => Container(height: 68, padding: const EdgeInsets.symmetric(horizontal: 22), decoration: const BoxDecoration(color: TivioColors.panel, border: Border(bottom: BorderSide(color: Colors.white10))), child: Row(children: [if (!isWide) IconButton(onPressed: () => setState(() => sidebarOpen = !sidebarOpen), icon: const Icon(Icons.menu)), const Text('TIVIO', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 4, color: TivioColors.cyan)), const SizedBox(width: 28), const Text('LIVE TV', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), SizedBox(width: 230, height: 38, child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: 'Search channels', prefixIcon: Icon(Icons.search), filled: true, fillColor: TivioColors.background, border: OutlineInputBorder(borderSide: BorderSide.none)))), IconButton(onPressed: () => setState(() => settings = !settings), icon: const Icon(Icons.tune_rounded))]));

  Widget _buildSidebar() => Container(width: 210, color: TivioColors.panel, padding: const EdgeInsets.fromLTRB(14, 24, 14, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(12), child: Text('BROWSE', style: TextStyle(color: TivioColors.muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.4))), ...categories.map((c) => _navItem(c, c == category ? Icons.radio : Icons.grid_view_rounded)), const Spacer(), _navItem('Favorites', Icons.favorite_rounded, favoritesOnly: true), const Padding(padding: EdgeInsets.all(12), child: Text('v1.0 • TIVIO', style: TextStyle(color: TivioColors.muted, fontSize: 11)))]));

  Widget _navItem(String label, IconData icon, {bool favoritesOnly = false}) => ListTile(dense: true, selected: (!favoritesOnly && label == category), selectedTileColor: TivioColors.cyan.withOpacity(.12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), leading: Icon(icon, size: 19, color: label == category ? TivioColors.cyan : TivioColors.muted), title: Text(label, style: TextStyle(color: label == category ? Colors.white : TivioColors.muted)), onTap: () => setState(() { category = favoritesOnly ? 'Favorites' : label; if (favoritesOnly) channels = channels; }));

  Widget _buildContent(bool isWide) => settings ? _buildSettings() : SingleChildScrollView(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildHero(isWide), const SizedBox(height: 24), Row(children: [const Text('CHANNELS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)), const Spacer(), Text('${visibleChannels.length} available', style: const TextStyle(color: TivioColors.muted))]), const SizedBox(height: 14), _buildChannels(isWide)]));

  Widget _buildHero(bool isWide) { final ch = current; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AspectRatio(aspectRatio: isWide ? 2.25 : 1.65, child: Container(decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)), child: _chewie != null ? ClipRRect(borderRadius: BorderRadius.circular(18), child: Chewie(controller: _chewie!)) : Center(child: reconnecting ? _recovery('Stream unavailable') : const CircularProgressIndicator(color: TivioColors.cyan)))), if (ch != null) Padding(padding: const EdgeInsets.only(top: 15), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(ch.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text('${ch.category}  •  ${ch.details}', style: const TextStyle(color: TivioColors.muted))])), IconButton(onPressed: () => _toggleFavorite(ch), icon: Icon(favorites.contains(ch.id) ? Icons.favorite : Icons.favorite_border, color: TivioColors.cyan))]))]); }

  Widget _buildChannels(bool isWide) { final list = category == 'Favorites' ? visibleChannels.where((c) => favorites.contains(c.id)).toList() : visibleChannels; return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: list.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isWide ? 4 : 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.45), itemBuilder: (_, i) { final ch = list[i]; final selected = ch.id == currentId; return InkWell(onTap: () => _tune(ch), borderRadius: BorderRadius.circular(14), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: selected ? TivioColors.cyan.withOpacity(.13) : TivioColors.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? TivioColors.cyan : Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [CircleAvatar(radius: 17, backgroundColor: TivioColors.panel2, backgroundImage: ch.logo.isEmpty ? null : NetworkImage(ch.logo), child: ch.logo.isEmpty ? const Icon(Icons.tv, size: 17, color: TivioColors.cyan) : null), const Spacer(), IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _toggleFavorite(ch), icon: Icon(favorites.contains(ch.id) ? Icons.favorite : Icons.favorite_border, size: 18, color: TivioColors.cyan))]), const Spacer(), Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(ch.category, style: const TextStyle(fontSize: 12, color: TivioColors.muted))]))); }); }

  Widget _buildSettings() => Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('SETTINGS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)), const SizedBox(height: 22), _setting('Playlist source', widget.playlistUrl ?? 'Built-in TIVIO demo playlist'), _setting('Playback', 'Live mode • Auto play enabled'), _setting('Channels', '${channels.length} loaded'), const SizedBox(height: 18), FilledButton.icon(onPressed: _loadPlaylist, icon: const Icon(Icons.refresh), label: const Text('Reload playlist'))]));
  Widget _setting(String title, String value) => ListTile(contentPadding: EdgeInsets.zero, title: Text(title), subtitle: Text(value, style: const TextStyle(color: TivioColors.muted)), trailing: const Icon(Icons.chevron_right, color: TivioColors.muted));

  final List<IptvChannel> _demoChannels = const [IptvChannel(id: 'tivio-one', name: 'TIVIO One', logo: '', category: 'Featured', program: 'Live now', details: 'TIVIO Originals', progress: .4, streamUrl: demoPlaylist), IptvChannel(id: 'tivio-cinema', name: 'TIVIO Cinema', logo: '', category: 'Movies', program: 'Now showing', details: 'Premium cinema', progress: .7, streamUrl: demoPlaylist), IptvChannel(id: 'tivio-sport', name: 'TIVIO Sport', logo: '', category: 'Sports', program: 'Live arena', details: 'All the action', progress: .55, streamUrl: demoPlaylist)];
}

extension FirstOrNullExtension<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
