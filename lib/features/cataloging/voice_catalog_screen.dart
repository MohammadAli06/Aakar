import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/mock_ai_service.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/voice_input_button.dart';
import '../../shared/widgets/attribute_confidence_widget.dart';
import '../../shared/widgets/glass_card.dart';

enum _CatalogStage { record, processing, attributes, followUp, done }

class VoiceCatalogScreen extends StatefulWidget {
  final String productId;
  const VoiceCatalogScreen({super.key, required this.productId});

  @override
  State<VoiceCatalogScreen> createState() => _VoiceCatalogScreenState();
}

class _VoiceCatalogScreenState extends State<VoiceCatalogScreen> {
  _CatalogStage _stage = _CatalogStage.record;
  bool _isListening = false;
  String _transcript = '';
  List<AttributeField> _attributes = [];
  List<AttributeField> get _missingAttributes =>
      _attributes.where((a) => (a.value == null || a.value!.isEmpty) && a.isRequired).toList();

  // Follow-up answers
  final Map<String, String> _followUpAnswers = {};
  int _followUpIndex = 0;
  final _answerController = TextEditingController();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _transcript = '';
    });
    // Simulate recording for 3 seconds, then transcribe
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _isListening = false);
    _processVoice();
  }

  Future<void> _processVoice() async {
    setState(() => _stage = _CatalogStage.processing);
    final text = await MockAIService.transcribeVoice('', 'hi');
    if (!mounted) return;
    setState(() => _transcript = text);
    final attrs = await MockAIService.extractAttributes(text, CraftCategory.pottery);
    if (!mounted) return;
    setState(() {
      _attributes = attrs;
      _stage = _missingAttributes.isNotEmpty
          ? _CatalogStage.followUp
          : _CatalogStage.attributes;
    });
  }

  void _submitFollowUp() {
    if (_answerController.text.trim().isEmpty) return;
    final missing = _missingAttributes;
    if (_followUpIndex < missing.length) {
      final key = missing[_followUpIndex].key;
      _followUpAnswers[key] = _answerController.text.trim();
      // Update attributes list
      setState(() {
        _attributes = _attributes.map((a) {
          if (a.key == key) {
            return a.copyWith(value: _answerController.text.trim(), confidence: 0.95);
          }
          return a;
        }).toList();
        _answerController.clear();
        if (_followUpIndex < missing.length - 1) {
          _followUpIndex++;
        } else {
          _stage = _CatalogStage.attributes;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('स्मार्ट कैटालॉग'),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _CatalogStage.record => _buildRecord(),
          _CatalogStage.processing => _buildProcessing(),
          _CatalogStage.followUp => _buildFollowUp(),
          _CatalogStage.attributes => _buildAttributes(),
          _CatalogStage.done => _buildDone(),
        },
      ),
    );
  }

  Widget _buildRecord() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Instruction card
          GlassCard(
            child: Column(
              children: [
                const Text(
                  '🎤 अपने उत्पाद के बारे में बताएं',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'जैसे: "यह मेरे हाथ से बना मिट्टी का मटका है, राजस्थान से, ऊँचाई 30 cm..."',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Speak freely about your product in any language.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Waveform
          SizedBox(
            height: 64,
            child: WaveformVisualizer(isActive: _isListening),
          ),
          const SizedBox(height: 32),
          // Mic button
          VoiceInputButton(
            isListening: _isListening,
            onTap: _isListening ? () {} : _startListening,
            size: 110,
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _isListening ? 'सुन रहा हूँ... बोलते रहें' : 'बोलने के लिए दबाएं',
              key: ValueKey(_isListening),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _isListening ? AppColors.accentRed : AppColors.textSecondary,
              ),
            ),
          ),
          if (!_isListening)
            const Text('Tap to speak', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
          const Spacer(),
          // Skip to demo
          TextButton(
            onPressed: _processVoice,
            child: const Text('Demo: Auto-fill', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textHint, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 30)],
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 28),
          const Text('AI समझ रहा है...', style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Analyzing your description...', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textHint)),
          const SizedBox(height: 24),
          const SizedBox(width: 200, child: LinearProgressIndicator(backgroundColor: AppColors.surface, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildFollowUp() {
    final missing = _missingAttributes;
    if (missing.isEmpty || _followUpIndex >= missing.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _stage = _CatalogStage.attributes);
      });
      return const SizedBox();
    }
    final current = missing[_followUpIndex];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          Row(
            children: [
              Text(
                'प्रश्न ${_followUpIndex + 1}/${missing.length}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint),
              ),
              const Spacer(),
              Text('${missing.length - _followUpIndex - 1} remaining',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_followUpIndex + 1) / missing.length,
              backgroundColor: AppColors.surface,
              color: AppColors.primary,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 20)],
            ),
            child: const Icon(Icons.question_mark_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 24),
          Text(
            '${current.labelHi} क्या है?',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'What is the ${current.labelEn}?',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _answerController,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '${current.labelHi} लिखें / Type ${current.labelEn}',
              hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
            ),
            onSubmitted: (_) => _submitFollowUp(),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _submitFollowUp,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: const Center(
                child: Text('अगला →', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAttributes() {
    return Column(
      children: [
        // Transcript banner
        if (_transcript.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.record_voice_over_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _transcript,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Text('🧠 AI ने समझा', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
                ),
                child: Text(
                  '${_attributes.where((a) => a.confidence >= 0.8).length}/${_attributes.length} High',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accentGreen),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            itemCount: _attributes.length,
            itemBuilder: (context, i) => AttributeConfidenceWidget(
              field: _attributes[i],
              onEdit: () => _showEditDialog(_attributes[i], i),
            ),
          ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: GestureDetector(
            onTap: () => context.push('/listing-preview', extra: widget.productId),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Listing बनाएं →', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return const Center(child: Text('Done'));
  }

  void _showEditDialog(AttributeField field, int index) {
    final controller = TextEditingController(text: field.value ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${field.labelHi} बदलें', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: field.labelEn),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _attributes[index] = field.copyWith(value: controller.text, confidence: 1.0);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
