import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class QuizQuestionOption {
  final String id;
  final String text;
  QuizQuestionOption({required this.id, required this.text});
  factory QuizQuestionOption.fromJson(Map<String, dynamic> j) =>
      QuizQuestionOption(id: j['id'] as String, text: j['text'] as String);
}

class QuizQuestion {
  final String id;
  final String text;
  final List<QuizQuestionOption> options;
  QuizQuestion({required this.id, required this.text, required this.options});
  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
    id: j['id'] as String,
    text: j['text'] as String,
    options:
        (j['options'] as List)
            .map((e) => QuizQuestionOption.fromJson(e as Map<String, dynamic>))
            .toList(),
  );
}

class ScoreUpdate {
  final String name;
  final int correct;
  final int incorrect;
  ScoreUpdate({
    required this.name,
    required this.correct,
    required this.incorrect,
  });
  factory ScoreUpdate.fromJson(Map<String, dynamic> j) => ScoreUpdate(
    name: j['name'] as String,
    correct: (j['correct'] as num).toInt(),
    incorrect: (j['incorrect'] as num).toInt(),
  );
}

class QuizWsService {
  WebSocketChannel? _ch;
  final _questionsCtrl = StreamController<List<QuizQuestion>>.broadcast();
  final _scoreCtrl = StreamController<ScoreUpdate>.broadcast();
  final _rawCtrl = StreamController<Map<String, dynamic>>.broadcast();

  // simpan state pertanyaan saat ini agar bisa diupdate realtime
  List<QuizQuestion> _currentQuestions = [];

  Stream<List<QuizQuestion>> get questionsStream => _questionsCtrl.stream;
  Stream<ScoreUpdate> get scoreStream => _scoreCtrl.stream;
  Stream<Map<String, dynamic>> get rawStream => _rawCtrl.stream;

  Uri _buildWsUri({String? override}) {
    if (override != null && override.isNotEmpty) return Uri.parse(override);
    if (kIsWeb) {
      final base = Uri.base; // origin aplikasi Flutter web
      final scheme = base.scheme == 'https' ? 'wss' : 'ws';
      // ubah port jika backend tidak di 3000
      return Uri(scheme: scheme, host: base.host, port: 3000, path: '/ws');
    }
    // Catatan: jika test di Android emulator, gunakan 10.0.2.2 sebagai host
    return Uri(scheme: 'ws', host: 'localhost', port: 3000, path: '/ws');
  }

  Future<void> connect({String? wsUrl}) async {
    final uri = _buildWsUri(override: wsUrl);
    _ch = WebSocketChannel.connect(uri);
    _ch!.stream.listen(
      _onMessage,
      onError: (e) => debugPrint('WS error: $e'),
      onDone: () => debugPrint('WS closed'),
    );
  }

  void _onMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      final payload = msg['payload'];
      if (type == null) return;

      _rawCtrl.add(msg);

      switch (type) {
        case 'student:questions':
          {
            final list =
                (payload as List)
                    .map(
                      (e) => QuizQuestion.fromJson(e as Map<String, dynamic>),
                    )
                    .toList();
            _currentQuestions = List.of(list);
            _questionsCtrl.add(List.of(_currentQuestions));
            break;
          }
        case 'question:added':
          {
            final q = QuizQuestion.fromJson(payload as Map<String, dynamic>);
            final idx = _currentQuestions.indexWhere((x) => x.id == q.id);
            if (idx >= 0) {
              _currentQuestions[idx] = q;
            } else {
              _currentQuestions.add(q);
            }
            _questionsCtrl.add(List.of(_currentQuestions));
            break;
          }
        case 'question:removed':
          {
            final id = (payload as Map<String, dynamic>)['id'] as String?;
            if (id != null) {
              _currentQuestions.removeWhere((x) => x.id == id);
              _questionsCtrl.add(List.of(_currentQuestions));
            }
            break;
          }
        case 'score:update':
          {
            _scoreCtrl.add(
              ScoreUpdate.fromJson(payload as Map<String, dynamic>),
            );
            break;
          }
        default:
          break;
      }
    } catch (e) {
      debugPrint('WS parse failed: $e');
    }
  }

  void joinAsStudent() {
    _send({'type': 'student:join'});
  }

  void sendAnswer({
    required String name,
    required String questionId,
    required String selectedOptionId,
  }) {
    _send({
      'type': 'student:answer',
      'payload': {
        'name': name,
        'questionId': questionId,
        'selectedOptionId': selectedOptionId,
      },
    });
  }

  void _send(Map<String, dynamic> msg) {
    final jsonStr = jsonEncode(msg);
    _ch?.sink.add(jsonStr);
  }

  Future<void> close() async {
    await _ch?.sink.close();
    await _questionsCtrl.close();
    await _scoreCtrl.close();
    await _rawCtrl.close();
  }
}
