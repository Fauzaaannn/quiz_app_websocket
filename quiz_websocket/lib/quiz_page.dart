import 'package:flutter/material.dart';
import 'services/ws_service.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _ws = QuizWsService();
  List<QuizQuestion> _questions = [];
  String _log = '';
  String? _studentName;
  String? _role;

  // Tambahan: tracking pertanyaan terjawab dan pending hide
  final Set<String> _answeredIds = {};
  final Set<String> _pendingHide = {};
  final int _hideDelayMs = 500; // atur delay dalam millisecond

  @override
  void initState() {
    super.initState();
    _initWs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ambil data dari Navigator arguments: {'userName': 'Nama', 'role': 'mahasiswa'}
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      setState(() {
        _studentName =
            (args['userName'] ?? args['displayName'] ?? args['name'])
                ?.toString();
        _role = args['role']?.toString();
      });
    }
  }

  Future<void> _initWs() async {
    await _ws
        .connect(); // atau _ws.connect(wsUrl: 'ws://192.168.1.10:3000/ws');
    _ws.joinAsStudent();
    _ws.questionsStream.listen((qs) {
      // Filter pertanyaan yang sudah dijawab agar tetap tersembunyi
      setState(
        () =>
            _questions = qs.where((q) => !_answeredIds.contains(q.id)).toList(),
      );
    });
    _ws.scoreStream.listen((s) {
      setState(() {
        _log = 'Score update -> ${s.name}: +${s.correct}/-${s.incorrect}';
      });
    });
  }

  @override
  void dispose() {
    _ws.close();
    super.dispose();
  }

  void _answer(QuizQuestion q, QuizQuestionOption opt) {
    // Hanya izinkan jika role == 'mahasiswa' dan nama tersedia
    if (_role?.toLowerCase() != 'mahasiswa') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya role "mahasiswa" yang bisa menjawab.'),
        ),
      );
      return;
    }
    final name = (_studentName ?? '').trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama pengguna tidak ditemukan.')),
      );
      return;
    }

    _ws.sendAnswer(name: name, questionId: q.id, selectedOptionId: opt.id);

    // Cegah tap ulang dan jadwalkan hide setelah delay
    setState(() {
      _pendingHide.add(q.id);
    });
    Future.delayed(Duration(milliseconds: _hideDelayMs), () {
      if (!mounted) return;
      setState(() {
        _answeredIds.add(q.id); // tandai sudah dijawab
        _pendingHide.remove(q.id); // hapus dari pending
        _questions.removeWhere((x) => x.id == q.id); // sembunyikan dari list
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz WS Demo')),
      body: Column(
        children: [
          if (_studentName != null || _role != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Login sebagai: ${_studentName ?? '-'} (${_role ?? '-'})',
              ),
            ),
          if (_log.isNotEmpty)
            Padding(padding: const EdgeInsets.all(8), child: Text(_log)),
          Expanded(
            child: ListView.builder(
              itemCount: _questions.length,
              itemBuilder: (ctx, i) {
                final q = _questions[i];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.text,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...q.options.map(
                          (o) => ListTile(
                            title: Text(o.text),
                            // Nonaktifkan tap jika bukan mahasiswa
                            onTap:
                                _role?.toLowerCase() == 'mahasiswa'
                                    ? () => _answer(q, o)
                                    : null,
                          ),
                        ),
                        if (_pendingHide.contains(q.id))
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Jawaban dikirim, pertanyaan akan disembunyikan...',
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
