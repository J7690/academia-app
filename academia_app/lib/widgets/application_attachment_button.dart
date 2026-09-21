import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../services/application_media_service.dart';

class ApplicationAttachmentButton extends StatelessWidget {
  const ApplicationAttachmentButton(
      {super.key,
      required this.applicationId,
      required this.sender,
      required this.channel,
      required this.onSent,
      this.enabled = true});
  final String applicationId;
  final String sender;
  final String channel;
  final Future<void> Function() onSent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!applicationMessageMediaEnabled) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Joindre une image, un vocal ou une vidéo',
      icon: const Icon(Icons.attach_file),
      onPressed: !enabled || applicationId.isEmpty
          ? null
          : () async {
              final sent = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _AttachmentDialog(
                      applicationId: applicationId,
                      sender: sender,
                      channel: channel));
              if (sent == true && context.mounted) await onSent();
            },
    );
  }
}

class _AttachmentDialog extends StatefulWidget {
  const _AttachmentDialog(
      {required this.applicationId,
      required this.sender,
      required this.channel});
  final String applicationId;
  final String sender;
  final String channel;
  @override
  State<_AttachmentDialog> createState() => _AttachmentDialogState();
}

class _AttachmentDialogState extends State<_AttachmentDialog>
    with WidgetsBindingObserver {
  final _caption = TextEditingController();
  ApplicationMediaFile? _file;
  String? _path;
  String? _error;
  bool _busy = false;
  bool _recording = false;
  bool _sent = false;
  int _seconds = 0;
  AudioRecorder? _recorder;
  AudioPlayer? _preview;
  StreamSubscription<Uint8List>? _recordStream;
  Completer<void>? _recordDone;
  Timer? _timer;
  final _pcm = BytesBuilder(copy: false);
  ApplicationMediaService? _service;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording && !_busy) {
      unawaited(_stopVoice());
    }
  }

  Future<void> _pick(String kind) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      ApplicationMediaFile? file;
      if (kind == 'file') {
        final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ApplicationMediaFile.formats.keys.toList(),
            withReadStream: true,
            withData: false);
        if (result == null || result.files.isEmpty) return;
        final selected = result.files.single;
        if (selected.size > ApplicationMediaFile.maxBytes) {
          throw const FormatException('Le fichier dépasse 25 Mo.');
        }
        final bytes = BytesBuilder(copy: false);
        final stream = selected.readStream;
        if (stream == null) {
          throw const FormatException('Impossible de lire ce fichier.');
        }
        await for (final chunk in stream) {
          bytes.add(chunk);
          if (bytes.length > ApplicationMediaFile.maxBytes) {
            throw const FormatException('Le fichier dépasse 25 Mo.');
          }
        }
        file = ApplicationMediaFile.fromBytes(bytes.takeBytes(), selected.name);
      } else {
        final picker = ImagePicker();
        final selected = kind == 'video'
            ? await picker.pickVideo(source: ImageSource.gallery)
            : await picker.pickImage(
                source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
        if (selected == null) return;
        if (await selected.length() > ApplicationMediaFile.maxBytes) {
          throw const FormatException('Le fichier dépasse 25 Mo.');
        }
        file = ApplicationMediaFile.fromBytes(
            await selected.readAsBytes(), selected.name);
      }
      if (mounted) setState(() => _file = file);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is FormatException
            ? e.message
            : 'Impossible de sélectionner ce média.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startVoice() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _recorder ??= AudioRecorder();
      if (!await _recorder!.hasPermission()) {
        throw StateError(
            'Autorisez le microphone dans les réglages pour enregistrer un vocal.');
      }
      if (!mounted) return;
      _pcm.clear();
      _recordDone = Completer<void>();
      final stream = await _recorder!.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
      if (!mounted) {
        await _recorder!.cancel();
        return;
      }
      _recordStream = stream.listen((bytes) {
        if (_pcm.length + bytes.length <= ApplicationMediaFile.maxBytes - 44) {
          _pcm.add(bytes);
        }
      }, onDone: () {
        if (!(_recordDone?.isCompleted ?? true)) _recordDone?.complete();
      }, onError: (Object error) {
        if (!(_recordDone?.isCompleted ?? true)) _recordDone?.complete();
        if (mounted) {
          setState(() => _error = 'Enregistrement interrompu. Réessayez.');
        }
      });
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 120 && !_busy) unawaited(_stopVoice());
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is StateError
            ? e.message
            : 'Microphone indisponible. Vous pouvez joindre un fichier audio.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopVoice() async {
    if (_busy) return;
    setState(() => _busy = true);
    _timer?.cancel();
    try {
      await _recorder?.stop();
      await _recordDone?.future.timeout(const Duration(seconds: 5));
      final pcm = _pcm.takeBytes();
      if (pcm.isEmpty) throw StateError('Aucun son enregistré.');
      final file =
          ApplicationMediaFile.fromBytes(applicationVoiceWav(pcm), 'vocal.wav');
      if (mounted) setState(() => _file = file);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de terminer le vocal. Réessayez.');
      }
    } finally {
      await _recordStream?.cancel();
      if (mounted) {
        setState(() {
          _busy = false;
          _recording = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final file = _file;
    if (file == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _preview?.stop();
      final service = _service ??= ApplicationMediaService();
      _path ??=
          await service.upload(widget.applicationId, widget.channel, file);
      await service.send(
          applicationId: widget.applicationId,
          sender: widget.sender,
          channel: widget.channel,
          file: file,
          path: _path!,
          caption: _caption.text);
      _sent = true;
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Envoi non confirmé. Vérifiez votre connexion et réessayez.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disposeMedia() async {
    try {
      await _recorder?.cancel();
    } catch (_) {}
    await _recorder?.dispose();
    await _recordStream?.cancel();
    await _preview?.dispose();
    if (!_sent && _path != null) await _service?.discard(_path!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _caption.dispose();
    unawaited(_disposeMedia());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final recipient = widget.sender != 'admin'
        ? 'Administration'
        : widget.channel == 'student'
            ? 'Étudiant'
            : 'Université';
    return PopScope(
        canPop: !_busy && !_recording,
        child: AlertDialog(
          title: Text('Pièce jointe → $recipient'),
          content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (file == null && !_recording) ...[
                    const Text(
                        '25 Mo maximum. Le fichier sera envoyé uniquement après confirmation.'),
                    TextButton.icon(
                        onPressed: _busy ? null : () => _pick('image'),
                        icon: const Icon(Icons.image),
                        label: const Text('Image')),
                    TextButton.icon(
                        onPressed: _busy ? null : () => _pick('video'),
                        icon: const Icon(Icons.video_library),
                        label: const Text('Vidéo')),
                    TextButton.icon(
                        onPressed: _busy ? null : () => _pick('file'),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Fichier image, audio ou vidéo')),
                    TextButton.icon(
                        onPressed: _busy ? null : _startVoice,
                        icon: const Icon(Icons.mic),
                        label: const Text('Enregistrer un vocal (2 min max.)')),
                  ],
                  if (_recording) ...[
                    Text('Enregistrement : $_seconds s / 120 s'),
                    TextButton.icon(
                        onPressed: _busy ? null : _stopVoice,
                        icon: const Icon(Icons.stop),
                        label: const Text('Terminer le vocal')),
                  ],
                  if (file != null) ...[
                    if (file.type == 'image')
                      Image.memory(file.bytes,
                          height: 180, fit: BoxFit.contain),
                    Text(
                        '${file.type == 'audio' ? 'Audio' : file.type == 'video' ? 'Vidéo' : 'Image'} — ${(file.bytes.length / (1024 * 1024)).toStringAsFixed(1)} Mo'),
                    if (file.type == 'audio')
                      TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  try {
                                    _preview ??= AudioPlayer();
                                    if (_preview!.state ==
                                        PlayerState.playing) {
                                      await _preview!.stop();
                                    } else {
                                      await _preview!.play(BytesSource(
                                          file.bytes,
                                          mimeType: file.mime));
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      setState(() => _error =
                                          'Écoute du vocal indisponible.');
                                    }
                                  }
                                },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Écouter / arrêter')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _caption,
                        enabled: !_busy,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Message (facultatif)')),
                  ],
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ],
              ))),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: file == null || _busy || _recording ? null : _send,
                child: const Text('Envoyer la pièce jointe')),
          ],
        ));
  }
}
