import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({Key? key}) : super(key: key);

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final TextEditingController _input = TextEditingController();
  final List<_Msg> _messages = [];
  bool _loading = false;

  // 추천 질문들
  final List<String> _suggestedQuestions = [
    "최근 사건 하나 알려줘",
    "서울역 가려고 하는데 피해서 가야할 곳 있을까?",
  ];

  Future<void> _send({String? fixed, bool debug = false}) async {
    final q = fixed ?? _input.text.trim();
    if (q.isEmpty || _loading) return;

    setState(() {
      _messages.add(_Msg('user', q));
      _loading = true;
    });
    _input.clear();

    try {
      final callable = functions.httpsCallable('chatRag');
      final resp = await callable.call({'question': q, 'topK': 5, 'debug': debug});
      final answer = (resp.data['answer'] ?? '').toString().trim();

      if (debug && resp.data['info'] != null) {
        print('DEBUG info: ${resp.data['info']}');
      }

      setState(() {
        _messages.add(_Msg('assistant', answer.isEmpty ? '응답이 없습니다.' : answer));
      });
    } catch (e) {
      setState(() {
        _messages.add(_Msg('assistant', '에러: $e'));
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // Firestore 데이터 확인용
  Future<void> _peek() async {
    try {
      final r = await functions.httpsCallable('peekData').call();
      print('peekData: ${r.data}');
      setState(() {
        _messages.add(_Msg(
            'assistant',
            '진단결과(콘솔 참조): projectId=${r.data['info']?['projectId']}, '
            'map_marker=${r.data['info']?['map_marker_count']}, '
            'report_community=${r.data['info']?['report_community_count']}'));
      });
    } catch (e) {
      setState(() {
        _messages.add(_Msg('assistant', 'peek 에러: $e'));
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 챗봇'),
        actions: [
          IconButton(
            tooltip: '데이터 진단(peekData)',
            onPressed: _peek,
            icon: const Icon(Icons.search),
          )
        ],
      ),
      body: Column(
        children: [
          // 🔹 추천 질문 버튼 영역
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: _suggestedQuestions.map((q) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: Text(q),
                    onPressed: () => _send(fixed: q), // 버튼 클릭 시 질문 전송
                    backgroundColor: Colors.grey[200],
                  ),
                );
              }).toList(),
            ),
          ),

          // 🔹 채팅 메시지 영역
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isUser = m.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.blue.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),

          // 🔹 입력창 영역
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '질문을 입력하세요...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loading ? null : () => _send(),
                    icon: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String role; // 'user' | 'assistant'
  final String text;
  _Msg(this.role, this.text);
}
