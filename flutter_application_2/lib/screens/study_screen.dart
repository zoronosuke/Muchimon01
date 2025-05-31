import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import './lesson_screen.dart';
import './chat_rooms_screen.dart';
import './chat_detail_screen.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  _StudyScreenState createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isLoadingUnits = true;

  // ムチモンとガクモンの声の設定
  int _muchimonVoiceId = 4; // ずんだもん (デフォルト)
  int _gakumonVoiceId = 10; // 玄野武宏 (デフォルト)

  // 保存されている声の設定を取得するキー
  static const String _muchimonVoiceKey = 'muchimon_voice_id';
  static const String _gakumonVoiceKey = 'gakumon_voice_id';

  // Rive animation controllers
  Artboard? _muchimonArtboard;
  Artboard? _godArtboard;
  RiveAnimationController? _muchimonController;
  RiveAnimationController? _godController;

  // 選択した学年、科目、章、節
  String? _selectedGrade;
  String? _selectedSubject;
  String? _selectedChapter;
  String? _selectedSection;

  // 利用可能な学習単元のリスト (Firestoreから取得)
  List<String> _availableGrades = [];
  Map<String, List<String>> _subjectsByGrade = {};
  Map<String, List<String>> _chaptersBySubject = {};
  Map<String, List<String>> _sectionsByChapter = {};

  @override
  void initState() {
    super.initState();
    _loadVoicePreferences();
    _loadAvailableUnits();
    _loadRiveAnimations();
  }

  // 声の設定を保存するメソッド
  Future<void> _saveVoicePreference(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
      print('音声設定を保存しました: $key = $value');
    } catch (e) {
      print('音声設定の保存に失敗しました: $e');
    }
  }

  // 声の設定を読み込むメソッド
  Future<void> _loadVoicePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _muchimonVoiceId = prefs.getInt(_muchimonVoiceKey) ?? 4;
        _gakumonVoiceId = prefs.getInt(_gakumonVoiceKey) ?? 10;
      });
      print('音声設定を読み込みました: ムチモン=$_muchimonVoiceId, ガクモン=$_gakumonVoiceId');
    } catch (e) {
      print('音声設定の読み込みに失敗しました: $e');
    }
  }

  // キャラクターをタップしたときの処理 (声の設定ダイアログを表示)
  void _showVoiceSelectionDialog(bool isMuchimon) {
    final title = isMuchimon ? 'ムチモンの声設定' : 'ガクモンの声設定';
    final currentValue = isMuchimon ? _muchimonVoiceId : _gakumonVoiceId;
    int selectedValue = currentValue; // ローカル変数で選択値を追跡

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 女性の声
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('女性の声',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          RadioListTile<int>(
                            title: const Text('四国めたん (ノーマル)'),
                            value: 1,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('四国めたん (あまあま)'),
                            value: 2,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('四国めたん (ツンツン)'),
                            value: 3,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('ずんだもん (ノーマル)'),
                            value: 4,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('もち子さん (ノーマル)'),
                            value: 5,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('つむぎ (ノーマル)'),
                            value: 6,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('雨晴はう (ノーマル)'),
                            value: 8,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('小夜/SAYO (ノーマル)'),
                            value: 46,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('春歌ナナ (ノーマル)'),
                            value: 49,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // 男性の声
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('男性の声',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          RadioListTile<int>(
                            title: const Text('玄野武宏 (ノーマル)'),
                            value: 10,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('白上虎太郎 (ふつう)'),
                            value: 12,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('青山龍星 (ノーマル)'),
                            value: 14,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('冥鳴ひまり (ノーマル)'),
                            value: 47,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // 特殊な声
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('特殊な声',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          RadioListTile<int>(
                            title: const Text('WhiteCUL (ノーマル)'),
                            value: 23,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('後鬼 (人間)'),
                            value: 27,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('No.7 (ノーマル)'),
                            value: 29,
                            groupValue: selectedValue,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedValue = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('設定する'),
              onPressed: () {
                Navigator.of(context).pop(selectedValue);
              },
            ),
          ],
        );
      },
    ).then((value) {
      if (value != null) {
        setState(() {
          if (isMuchimon) {
            _muchimonVoiceId = value;
            _saveVoicePreference(_muchimonVoiceKey, value);
          } else {
            _gakumonVoiceId = value;
            _saveVoicePreference(_gakumonVoiceKey, value);
          }
        });

        // 選択した声を確認するためのメッセージを表示
        final characterName = isMuchimon ? 'ムチモン' : 'ガクモン';
        final voiceName = _getVoiceName(value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$characterNameの声を「$voiceName」に変更しました'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  // 音声IDから名前を取得するヘルパーメソッド
  String _getVoiceName(int voiceId) {
    switch (voiceId) {
      case 1:
        return '四国めたん (ノーマル)';
      case 2:
        return '四国めたん (あまあま)';
      case 3:
        return '四国めたん (ツンツン)';
      case 4:
        return 'ずんだもん (ノーマル)';
      case 5:
        return 'もち子さん (ノーマル)';
      case 6:
        return 'つむぎ (ノーマル)';
      case 8:
        return '雨晴はう (ノーマル)';
      case 10:
        return '玄野武宏 (ノーマル)';
      case 12:
        return '白上虎太郎 (ふつう)';
      case 14:
        return '青山龍星 (ノーマル)';
      case 23:
        return 'WhiteCUL (ノーマル)';
      case 27:
        return '後鬼 (人間)';
      case 29:
        return 'No.7 (ノーマル)';
      case 46:
        return '小夜/SAYO (ノーマル)';
      case 47:
        return '冥鳴ひまり (ノーマル)';
      case 49:
        return '春歌ナナ (ノーマル)';
      default:
        return '不明な音声 ($voiceId)';
    }
  }

  // Load Rive animations
  void _loadRiveAnimations() {
    // Load Muchimon animation
    RiveFile.asset('assets/animations/muchimon01.riv').then((file) {
      final artboard = file.mainArtboard;

      // Get animation names
      List<String> animationNames = [];
      for (final animation in file.mainArtboard.animations) {
        animationNames.add(animation.name);
      }

      // Set default animation
      if (animationNames.isNotEmpty) {
        _muchimonController = SimpleAnimation(animationNames.first);
        artboard.addController(_muchimonController!);
      }

      setState(() {
        _muchimonArtboard = artboard;
      });
    }).catchError((error) {
      print('Error loading Muchimon Rive file: $error');
    });

    // Load God animation
    RiveFile.asset('assets/animations/god.riv').then((file) {
      final artboard = file.mainArtboard;

      // Get animation names
      List<String> animationNames = [];
      for (final animation in file.mainArtboard.animations) {
        animationNames.add(animation.name);
      }

      // Set default animation
      if (animationNames.isNotEmpty) {
        _godController = SimpleAnimation(animationNames.first);
        artboard.addController(_godController!);
      }

      setState(() {
        _godArtboard = artboard;
      });
    }).catchError((error) {
      print('Error loading God Rive file: $error');
    });
  }

  // Firestoreから利用可能な学習単元を取得
  Future<void> _loadAvailableUnits() async {
    setState(() {
      _isLoadingUnits = true;
    });

    try {
      final response = await _apiService.getAvailableStudyUnits();

      setState(() {
        _availableGrades = List<String>.from(response['grades'] ?? []);

        // _subjectsByGradeのデータ変換
        Map<String, dynamic> subjectsData = response['subjectsByGrade'] ?? {};
        _subjectsByGrade = {};
        subjectsData.forEach((grade, subjects) {
          _subjectsByGrade[grade] = List<String>.from(subjects);
        });

        // _chaptersBySubjectのデータ変換
        Map<String, dynamic> chaptersData = response['chaptersBySubject'] ?? {};
        _chaptersBySubject = {};
        chaptersData.forEach((subject, chapters) {
          _chaptersBySubject[subject] = List<String>.from(chapters);
        });

        // _sectionsByChapterのデータ変換
        Map<String, dynamic> sectionsData = response['sectionsByChapter'] ?? {};
        _sectionsByChapter = {};
        sectionsData.forEach((chapterKey, sections) {
          _sectionsByChapter[chapterKey] = List<String>.from(sections);
        });

        // 初期選択の設定
        if (_availableGrades.isNotEmpty) {
          _selectedGrade = _availableGrades.first;

          if (_subjectsByGrade[_selectedGrade]?.isNotEmpty ?? false) {
            _selectedSubject = _subjectsByGrade[_selectedGrade]!.first;

            if (_chaptersBySubject[_selectedSubject]?.isNotEmpty ?? false) {
              _selectedChapter = _chaptersBySubject[_selectedSubject]!.first;

              final chapterKey = '${_selectedSubject}_${_selectedChapter}';
              if (_sectionsByChapter[chapterKey]?.isNotEmpty ?? false) {
                _selectedSection = _sectionsByChapter[chapterKey]!.first;
              }
            }
          }
        }
      });
    } catch (e) {
      print('学習単元の取得に失敗しました: $e');
      // エラー時にデフォルト値を設定
      setState(() {
        _availableGrades = ['中1'];
        _subjectsByGrade = {
          '中1': ['数学']
        };
        _chaptersBySubject = {
          '数学': ['1章']
        };
        _sectionsByChapter = {
          '数学_1章': ['1節①', '1節②']
        };

        // デフォルト選択の設定
        _selectedGrade = '中1';
        _selectedSubject = '数学';
        _selectedChapter = '1章';
        _selectedSection = '1節①';
      });
    } finally {
      setState(() {
        _isLoadingUnits = false;
      });
    }
  }

  // 選択した単元のAPIアシスタント名を取得
  String get _selectedAssistantName {
    if (_selectedGrade == '中1' && _selectedSubject == '数学') {
      if (_selectedChapter == '1章') {
        if (_selectedSection == '1節①') {
          return '正の数負の数 基本概念';
        } else if (_selectedSection == '1節②') {
          return '正の数負の数 応用';
        }
      }
    }
    // デフォルト値
    return '$_selectedGrade $_selectedSubject ${_selectedChapter} ${_selectedSection} アシスタント';
  }

  // 学年が変更されたときの処理
  void _onGradeChanged(String? grade) {
    if (grade != null && grade != _selectedGrade) {
      setState(() {
        _selectedGrade = grade;
        // 選択した学年で利用可能な科目の最初のものを選択
        _selectedSubject = _subjectsByGrade[grade]?.first ?? '数学';
        // 新しく選択された科目で利用可能な章の最初のものを選択
        _selectedChapter = _chaptersBySubject[_selectedSubject]?.first ?? '1章';
        // 新しく選択された章で利用可能な節の最初のものを選択
        final chapterKey = '${_selectedSubject}_${_selectedChapter}';
        _selectedSection = _sectionsByChapter[chapterKey]?.first ?? '1節';
      });
    }
  }

  // 科目が変更されたときの処理
  void _onSubjectChanged(String? subject) {
    if (subject != null && subject != _selectedSubject) {
      setState(() {
        _selectedSubject = subject;
        // 新しく選択された科目で利用可能な章の最初のものを選択
        _selectedChapter = _chaptersBySubject[subject]?.first ?? '1章';
        // 新しく選択された章で利用可能な節の最初のものを選択
        final chapterKey = '${subject}_${_selectedChapter}';
        _selectedSection = _sectionsByChapter[chapterKey]?.first ?? '1節';
      });
    }
  }

  // 章が変更されたときの処理
  void _onChapterChanged(String? chapter) {
    if (chapter != null && chapter != _selectedChapter) {
      setState(() {
        _selectedChapter = chapter;
        // 新しく選択された章で利用可能な節の最初のものを選択
        final chapterKey = '${_selectedSubject}_${chapter}';
        _selectedSection = _sectionsByChapter[chapterKey]?.first ?? '1節';
      });
    }
  }

  // 節が変更されたときの処理
  void _onSectionChanged(String? section) {
    if (section != null) {
      setState(() {
        _selectedSection = section;
      });
    }
  }

  Future<void> _startStudySession() async {
    setState(() => _isLoading = true);

    try {
      // 選択した単元に基づいてチャットルーム名とメタデータを設定
      final String roomName =
          '$_selectedGrade $_selectedSubject $_selectedChapter $_selectedSection の学習';

      // メタデータに学年、科目、章、節、音声設定の情報を含める
      Map<String, dynamic> metadata = {
        'language': 'ja',
        'grade': _selectedGrade,
        'subject': _selectedSubject,
        'chapter': _selectedChapter,
        'section': _selectedSection,
        'assistant': _selectedAssistantName,
        'muchimon_voice_id': _muchimonVoiceId,
        'gakumon_voice_id': _gakumonVoiceId,
      };

      // 学習用のチャットルームを作成
      final response = await _apiService.createChatRoom(
        name: roomName,
        topic:
            '$_selectedGrade $_selectedSubject $_selectedChapter $_selectedSection',
        metadata: metadata,
      );

      print('学習チャットルーム作成: $response');

      if (!mounted) return;

      // 新しく作成したチャットルームに移動
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            roomId: response['roomId'],
            roomName: response['name'],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('チャットルームの作成に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _muchimonController?.dispose();
    _godController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('勉強する'),
        automaticallyImplyLeading: false,
      ),
      body: Row(
        children: [
          // Left side animation (Muchimon) - タップで声設定ダイアログを表示
          _muchimonArtboard != null
              ? SizedBox(
                  width: 120, // Larger size
                  child: GestureDetector(
                    onTap: () => _showVoiceSelectionDialog(true), // ムチモンの設定
                    child: Stack(
                      children: [
                        Rive(
                          artboard: _muchimonArtboard!,
                          fit: BoxFit.contain,
                        ),
                        // ヒントラベル
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: const Text(
                              'タップして声を設定 (ムチモン)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: 120),

          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoadingUnits)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('利用可能な学習単元を読み込み中...'),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 単元選択カード
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '学習する単元を選択してください',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),

                                // 学年選択
                                Row(
                                  children: [
                                    const SizedBox(
                                        width: 80, child: Text('学年:')),
                                    Expanded(
                                      child: _availableGrades.isEmpty
                                          ? const Text('利用可能な学年がありません')
                                          : DropdownButtonFormField<String>(
                                              value: _selectedGrade,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                              ),
                                              items: _availableGrades
                                                  .map((String grade) {
                                                return DropdownMenuItem<String>(
                                                  value: grade,
                                                  child: Text(grade),
                                                );
                                              }).toList(),
                                              onChanged: _onGradeChanged,
                                            ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 科目選択
                                Row(
                                  children: [
                                    const SizedBox(
                                        width: 80, child: Text('科目:')),
                                    Expanded(
                                      child: (_subjectsByGrade[
                                                      _selectedGrade] ??
                                                  [])
                                              .isEmpty
                                          ? const Text('利用可能な科目がありません')
                                          : DropdownButtonFormField<String>(
                                              value: _selectedSubject,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                              ),
                                              items: (_subjectsByGrade[
                                                          _selectedGrade] ??
                                                      [])
                                                  .map((String subject) {
                                                return DropdownMenuItem<String>(
                                                  value: subject,
                                                  child: Text(subject),
                                                );
                                              }).toList(),
                                              onChanged: _onSubjectChanged,
                                            ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 章選択
                                Row(
                                  children: [
                                    const SizedBox(
                                        width: 80, child: Text('章:')),
                                    Expanded(
                                      child: (_chaptersBySubject[
                                                      _selectedSubject] ??
                                                  [])
                                              .isEmpty
                                          ? const Text('利用可能な章がありません')
                                          : DropdownButtonFormField<String>(
                                              value: _selectedChapter,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                              ),
                                              items: (_chaptersBySubject[
                                                          _selectedSubject] ??
                                                      [])
                                                  .map((String chapter) {
                                                return DropdownMenuItem<String>(
                                                  value: chapter,
                                                  child: Text(chapter),
                                                );
                                              }).toList(),
                                              onChanged: _onChapterChanged,
                                            ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 節選択
                                Row(
                                  children: [
                                    const SizedBox(
                                        width: 80, child: Text('節:')),
                                    Expanded(
                                      child: (_sectionsByChapter[
                                                      '${_selectedSubject}_${_selectedChapter}'] ??
                                                  [])
                                              .isEmpty
                                          ? const Text('利用可能な節がありません')
                                          : DropdownButtonFormField<String>(
                                              value: _selectedSection,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                              ),
                                              items: (_sectionsByChapter[
                                                          '${_selectedSubject}_${_selectedChapter}'] ??
                                                      [])
                                                  .map((String section) {
                                                return DropdownMenuItem<String>(
                                                  value: section,
                                                  child: Text(section),
                                                );
                                              }).toList(),
                                              onChanged: _onSectionChanged,
                                            ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                if (_selectedSubject != null &&
                                    _selectedChapter != null &&
                                    _selectedSection != null)
                                  Text(
                                    'アシスタント: $_selectedAssistantName',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blue,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 学習開始ボタン
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          ElevatedButton(
                            onPressed: _availableGrades.isEmpty ||
                                    (_subjectsByGrade[_selectedGrade] ?? [])
                                        .isEmpty ||
                                    (_chaptersBySubject[_selectedSubject] ?? [])
                                        .isEmpty ||
                                    (_sectionsByChapter[
                                                '${_selectedSubject}_${_selectedChapter}'] ??
                                            [])
                                        .isEmpty
                                ? null // 利用可能な単元がない場合はボタンを無効化
                                : _startStudySession,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 16),
                            ),
                            child: const Text('勉強を始める',
                                style: TextStyle(fontSize: 18)),
                          ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // チャット履歴ボタン
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ChatRoomsScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                    ),
                    child:
                        const Text('チャット履歴一覧', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),

          // Right side animation (God/Gakumon) - タップで声設定ダイアログを表示
          _godArtboard != null
              ? SizedBox(
                  width: 120, // Larger size
                  child: GestureDetector(
                    onTap: () => _showVoiceSelectionDialog(false), // ガクモンの設定
                    child: Stack(
                      children: [
                        Rive(
                          artboard: _godArtboard!,
                          fit: BoxFit.contain,
                        ),
                        // ヒントラベル
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: const Text(
                              'タップして声を設定 (ガクモン)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: 120),
        ],
      ),
    );
  }
}
