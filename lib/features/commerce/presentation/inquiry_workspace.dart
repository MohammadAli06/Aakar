import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../data/commerce_repository.dart';
import '../domain/commerce_engine.dart';
import 'craft_widgets.dart';

/// A single shared thread, with request and quotation kept beside the chat.
class InquiryWorkspace extends StatefulWidget {
  final Record inquiry;
  final CommerceRepository repository;
  final List<Widget> request, quotation;

  /// Which tab to open on: 0 Request, 1 Chat, 2 Quotation. A message
  /// notification opens the conversation directly.
  final int initialTab;
  const InquiryWorkspace(
      {super.key,
      required this.inquiry,
      required this.repository,
      required this.request,
      required this.quotation,
      this.initialTab = 0});
  @override
  State<InquiryWorkspace> createState() => _InquiryWorkspaceState();
}

class _InquiryWorkspaceState extends State<InquiryWorkspace>
    with WidgetsBindingObserver {
  Timer? _poll;
  bool _refreshing = false, _foreground = true;
  String? _refreshError;
  String t(String en, String hi) => bilingual(context, en, hi);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing ||
        !_foreground ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _refreshing = true;
    try {
      await widget.repository.refreshInquiry('${widget.inquiry['id']}');
      if (mounted && _refreshError != null)
        setState(() => _refreshError = null);
    } catch (_) {
      if (mounted)
        setState(() => _refreshError = t(
            'Could not refresh. Your draft is safe. Pull down to retry.',
            'अपडेट नहीं हुआ। मसौदा सुरक्षित है। फिर कोशिश करें।'));
    } finally {
      _refreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.inquiry;
    final buyer = widget.repository.role == 'buyer';
    final name = r[buyer ? 'artisan_name' : 'buyer_name'] ??
        widget.repository.lookup(
            'profiles', '${r[buyer ? 'artisan_id' : 'buyer_id']}')?['name'] ??
        t('Participant', 'सदस्य');
    final capacity = '${r['capacity_status']}';
    final hasQuotes = records(r['quotes']).isNotEmpty;
    final next = r['status'] == 'ordered'
        ? t('Agreement confirmed', 'सहमति की पुष्टि हो गई')
        : (capacity == 'pending' && !hasQuotes)
            ? (buyer
                ? t('Waiting for the artisan’s capacity response',
                    'कारीगर की क्षमता के जवाब की प्रतीक्षा')
                : t('Next: check the request and confirm your capacity',
                    'अगला: ज़रूरत देखें और क्षमता बताएँ'))
            : capacity == 'declined'
                ? t('Capacity declined · discuss alternatives in chat',
                    'क्षमता अस्वीकृत · चैट में विकल्प पूछें')
                : !hasQuotes
                    ? (buyer
                        ? t('Capacity received · waiting for quotation',
                            'क्षमता प्राप्त · भाव की प्रतीक्षा')
                        : t('Next: prepare your quotation',
                            'अगला: अपना भाव तैयार करें'))
                    : t('Review the latest quotation and agree the terms',
                        'नया भाव जाँचें और शर्तें तय करें');
    return DefaultTabController(
        length: 3,
        initialIndex: widget.initialTab,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                          backgroundColor: const Color(0xFFE4EEE5),
                          child: Icon(buyer
                              ? Icons.handyman_outlined
                              : Icons.storefront_outlined)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('$name',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text('${r['product_title']}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ]))
                    ]),
                    const SizedBox(height: 8),
                    Text(next,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF285448))),
                    if (_refreshError != null)
                      Text(_refreshError!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.deepOrange)),
                  ])),
          TabBar(labelColor: const Color(0xFF285448), tabs: [
            Tab(text: t('Request', 'ज़रूरत')),
            Tab(text: t('Chat', 'चैट')),
            Tab(text: t('Quotation', 'भाव'))
          ]),
          Expanded(
              child: TabBarView(children: [
            RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: widget.request)),
            InquiryChat(
                key: ValueKey(r['id']),
                inquiry: r,
                repository: widget.repository),
            RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: widget.quotation)),
          ])),
        ]));
  }
}

/// Review is explicit; the original cannot be overwritten by the AI draft.
Future<Record?> reviewCommunication(
    BuildContext context, Record preview) async {
  String t(String en, String hi) => bilingual(context, en, hi);
  final controller =
      TextEditingController(text: '${preview['translation'] ?? ''}');
  final result = await showDialog<Record>(
      context: context,
      builder: (dialog) => AlertDialog(
            title: Text(t('Review before sending', 'भेजने से पहले जाँचें')),
            content: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t('Original message', 'मूल संदेश'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('${preview['text']}'),
                  const SizedBox(height: 16),
                  if (preview['status'] == 'review_required') ...[
                    Text(t(
                        'AI translation · check quantities, prices and deadlines',
                        'AI अनुवाद · मात्रा, कीमत और समय जाँचें')),
                    TextField(
                        controller: controller,
                        minLines: 3,
                        maxLines: 8,
                        decoration: InputDecoration(
                            labelText: t('Translation (editable)',
                                'अनुवाद (बदल सकते हैं)'))),
                  ] else
                    Text(preview['status'] == 'same_language'
                        ? t('You both prefer the same language. No translation is needed.',
                            'दोनों की पसंदीदा भाषा समान है। अनुवाद की ज़रूरत नहीं है।')
                        : t('Translation is unavailable. You can send the original or try again later.',
                            'अनुवाद उपलब्ध नहीं है। मूल संदेश भेजें या बाद में कोशिश करें।')),
                ])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: Text(t('Back', 'वापस'))),
              FilledButton(
                  onPressed: () => Navigator.pop(dialog,
                      {...preview, 'translation': controller.text.trim()}),
                  child: Text(t('Confirm & send', 'पुष्टि करके भेजें')))
            ],
          ));
  // Let the closing dialog finish using its controller.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  controller.dispose();
  return result;
}

class InquiryChat extends StatefulWidget {
  final Record inquiry;
  final CommerceRepository repository;
  const InquiryChat(
      {super.key, required this.inquiry, required this.repository});
  @override
  State<InquiryChat> createState() => _InquiryChatState();
}

class _InquiryChatState extends State<InquiryChat> with WidgetsBindingObserver {
  final _text = TextEditingController(), _scroll = ScrollController();
  AudioRecorder? _recorder;
  Timer? _timer;
  String? _voicePath, _error;
  bool _recording = false, _working = false;
  int _seconds = 0;
  String t(String en, String hi) => bilingual(context, en, hi);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bottom();
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients)
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
      });
  @override
  void didUpdateWidget(covariant InquiryChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (records(oldWidget.inquiry['messages']).length !=
            records(widget.inquiry['messages']).length &&
        (!_scroll.hasClients || _scroll.position.extentAfter < 180)) _bottom();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording) _stop();
  }

  Future<void> _deleteVoice() async {
    final path = _voicePath;
    if (mounted)
      setState(() {
        _voicePath = null;
        _seconds = 0;
      });
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<void> _start() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      _recorder ??= AudioRecorder();
      if (!await _recorder!.hasPermission())
        throw WorkflowError(t(
            'Microphone permission is needed to record a voice note.',
            'वॉइस नोट के लिए माइक्रोफ़ोन की अनुमति दें।'));
      final temp = await getTemporaryDirectory();
      final path =
          '${temp.path}/inquiry-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder!.start(
          const RecordConfig(
              encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 24000),
          path: path);
      if (!mounted) {
        await _recorder!.cancel();
        return;
      }
      setState(() {
        _recording = true;
        _seconds = 0;
        _voicePath = path;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
        if (_seconds >= 120) _stop();
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _timer?.cancel();
    setState(() {
      _recording = false;
      _working = true;
    });
    try {
      final path = await _recorder?.stop();
      if (mounted) setState(() => _voicePath = path);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sendText() async {
    final original = _text.text;
    if (original.trim().isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      Record preview;
      try {
        preview = await widget.repository
            .previewMessage(original, inquiry: widget.inquiry);
      } catch (_) {
        preview = {
          'text': original,
          'translation': '',
          'status': 'unavailable'
        };
      }
      if (!mounted) return;
      final reviewed = preview['status'] == 'same_language'
          ? preview
          : await reviewCommunication(context, preview);
      if (reviewed == null || !mounted) return;
      await widget.repository.act('message',
          {...reviewed, 'text': original, 'id': widget.inquiry['id']});
      _text.clear();
      _bottom();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sendVoice() async {
    if (_voicePath == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.repository.sendVoice(widget.inquiry, _voicePath!);
      await _deleteVoice();
      _bottom();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _recorder?.dispose();
    _text.dispose();
    _scroll.dispose();
    final path = _voicePath;
    if (path != null) File(path).delete().catchError((_) => File(path));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.inquiry, repo = widget.repository;
    final messages = records(r['messages']);
    final same = r['buyer_language'] != null &&
        r['buyer_language'] == r['artisan_language'];
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
              same
                  ? t('Same preferred language · original text',
                      'समान पसंदीदा भाषा · मूल संदेश')
                  : t('Text bridge follows your saved languages · voice notes stay original',
                      'सहेजी गई भाषा में टेक्स्ट अनुवाद · वॉइस नोट मूल ही रहेंगे'),
              style: const TextStyle(fontSize: 10))),
      Expanded(
          child: RefreshIndicator(
              onRefresh: () => repo.refreshInquiry('${r['id']}'),
              child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    if (messages.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                              t('Discuss specifications, availability and delivery here. Agreed prices belong in a quotation.',
                                  'विवरण, उपलब्धता और डिलीवरी पर बात करें। तय कीमत भाव में दर्ज करें।'),
                              textAlign: TextAlign.center)),
                    ...messages.map((m) {
                      final mine = m['role'] == repo.role;
                      final date = DateTime.tryParse('${m['time']}')?.toLocal();
                      return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                              constraints: const BoxConstraints(maxWidth: 310),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: mine
                                      ? const Color(0xFFE1ECE5)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        mine
                                            ? t('You', 'आप')
                                            : (m['role'] == 'buyer'
                                                ? t('Buyer', 'खरीदार')
                                                : t('Artisan', 'कारीगर')),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600)),
                                    if (m['kind'] == 'voice')
                                      VoiceNotePlayer(
                                          key: ValueKey(m['id']),
                                          load: () async {
                                            final bytes = await repo.voiceBytes(
                                                '${r['id']}', '${m['voice']}');
                                            final temp =
                                                await getTemporaryDirectory();
                                            final file = File(
                                                '${temp.path}/voice-${m['id']}.m4a');
                                            await file.writeAsBytes(bytes);
                                            return file.path;
                                          })
                                    else ...[
                                      SelectableText('${m['text'] ?? ''}',
                                          style: const TextStyle(
                                              fontSize: 13, height: 1.5)),
                                      if ('${m['translation'] ?? ''}'
                                          .isNotEmpty) ...[
                                        const Divider(),
                                        Text(
                                            t('Reviewed translation',
                                                'जाँचा हुआ अनुवाद'),
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF285448))),
                                        SelectableText('${m['translation']}',
                                            style: const TextStyle(
                                                fontSize: 13, height: 1.5))
                                      ],
                                    ],
                                    if (date != null)
                                      Text(
                                          '${date.day}/${date.month} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.black54)),
                                  ])));
                    }),
                  ]))),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 11))),
      if (_working) const LinearProgressIndicator(minHeight: 2),
      Container(
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: SafeArea(
              top: false,
              child: _recording
                  ? Row(children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              '${t('Recording', 'रिकॉर्डिंग')} $_seconds / 120s')),
                      IconButton(
                          tooltip: t('Stop recording', 'रिकॉर्डिंग रोकें'),
                          onPressed: _working ? null : _stop,
                          icon: const Icon(Icons.stop_circle))
                    ])
                  : _voicePath != null
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                              t('Preview your voice note · no translation',
                                  'वॉइस नोट सुनें · अनुवाद नहीं होगा'),
                              style: const TextStyle(fontSize: 11)),
                          Row(children: [
                            Expanded(
                                child: VoiceNotePlayer(
                                    key: ValueKey(_voicePath),
                                    load: () async => _voicePath!,
                                    deleteOnDispose: false)),
                            IconButton(
                                tooltip:
                                    t('Discard recording', 'रिकॉर्डिंग हटाएँ'),
                                onPressed: _working ? null : _deleteVoice,
                                icon: const Icon(Icons.delete_outline)),
                            IconButton(
                                tooltip: t('Send voice note', 'वॉइस नोट भेजें'),
                                onPressed: _working ? null : _sendVoice,
                                icon: const Icon(Icons.send))
                          ]),
                        ])
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                              Expanded(
                                  child: TextField(
                                      controller: _text,
                                      enabled: !_working,
                                      minLines: 1,
                                      maxLines: 4,
                                      maxLength: 6000,
                                      decoration: InputDecoration(
                                          hintText:
                                              t('Message…', 'संदेश लिखें…'),
                                          counterText: '',
                                          border: const OutlineInputBorder()))),
                              IconButton(
                                  tooltip: t('Record voice note',
                                      'वॉइस नोट रिकॉर्ड करें'),
                                  onPressed: _working || r['server'] != true
                                      ? null
                                      : _start,
                                  icon: const Icon(Icons.mic_none)),
                              IconButton(
                                  tooltip: t('Send message', 'संदेश भेजें'),
                                  onPressed: _working ? null : _sendText,
                                  icon: const Icon(Icons.send,
                                      color: Color(0xFF285448))),
                            ]))),
    ]);
  }
}

class VoiceNotePlayer extends StatefulWidget {
  final Future<String> Function() load;
  final bool deleteOnDispose;
  const VoiceNotePlayer(
      {super.key, required this.load, this.deleteOnDispose = true});
  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  AudioPlayer? _player;
  StreamSubscription? _state, _position;
  bool _playing = false, _loading = false;
  String? _path, _error;
  int _seconds = 0;
  Future<void> _play() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_player == null) {
        _player = AudioPlayer();
        _state = _player!.onPlayerStateChanged.listen((s) {
          if (mounted) setState(() => _playing = s == PlayerState.playing);
        });
        _position = _player!.onPositionChanged.listen((p) {
          if (mounted) setState(() => _seconds = p.inSeconds);
        });
      }
      if (_playing) {
        await _player!.pause();
      } else {
        _path ??= await widget.load();
        if (mounted) await _player!.play(DeviceFileSource(_path!));
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = bilingual(context,
            'Could not play. Tap to retry.', 'नहीं चला। फिर कोशिश करें।'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _state?.cancel();
    _position?.cancel();
    _player?.dispose();
    final path = _path;
    if (path != null && widget.deleteOnDispose)
      File(path).delete().catchError((_) => File(path));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: bilingual(
                context, 'Play / pause voice note', 'वॉइस नोट चलाएँ / रोकें'),
            onPressed: _loading ? null : _play,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_playing ? Icons.pause_circle : Icons.play_circle)),
        Flexible(
            child: Text(
                _error ??
                    '${bilingual(context, 'Voice note', 'वॉइस नोट')} · ${_seconds}s',
                style: const TextStyle(fontSize: 11))),
      ]);
}
