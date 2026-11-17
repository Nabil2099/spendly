import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../expenses/presentation/expense_cubit.dart';
import '../data/gemini_chat_service.dart';
import 'ai_chat_cubit.dart';

/// AI financial advisor chat screen powered by Gemini (`gemini-3.5-flash-lite`).
class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  static const _quickPrompts = [
    'How is my budget looking?',
    'Where can I cut spending?',
    'Summarize my month',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    if (preset == null) _controller.clear();

    final expenseState = context.read<ExpenseCubit>().state;
    context.read<AiChatCubit>().sendMessage(text, expenseState: expenseState);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go(AppRoutes.dashboard),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.slateBlue,
              size: 20,
            ),
            SizedBox(width: 8),
            Text('Spendly AI Advisor'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: () => context.read<AiChatCubit>().clearChat(),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: BlocConsumer<AiChatCubit, AiChatState>(
              listener: (context, state) => _scrollToBottom(),
              builder: (context, state) {
                return Column(
                  children: [
                    if (!state.isConfigured)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.warmSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.sandyAccent),
                          ),
                          child: const Text(
                            'Gemini API key not configured. Add `GEMINI_API_KEY=your_key` to `.env` and restart the app.',
                            style: TextStyle(
                              color: AppColors.darkPlum,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: state.messages.isEmpty
                          ? _EmptyChatView(
                              modelName: state.modelName,
                              onSelectPrompt: _send,
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                16,
                              ),
                              itemCount:
                                  state.messages.length +
                                  (state.isSending ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                if (index == state.messages.length) {
                                  return const _TypingBubble();
                                }
                                return _MessageBubble(
                                  message: state.messages[index],
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        border: Border(
                          top: BorderSide(color: context.borderColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              enabled: !state.isSending,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: const InputDecoration(
                                hintText: 'Ask for budgeting advice...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: state.isSending ? null : () => _send(),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(50, 50),
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child: const Icon(Icons.send_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView({required this.modelName, required this.onSelectPrompt});

  final String modelName;
  final ValueChanged<String> onSelectPrompt;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.slateBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.slateBlue,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text('Ask Spendly AI', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Get personalized EGP budgeting tips based on your monthly expenses ($modelName).',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _AiAdvisorScreenState._quickPrompts.map((prompt) {
              return ActionChip(
                label: Text(prompt),
                backgroundColor: context.cardBg,
                side: BorderSide(color: context.borderColor),
                onPressed: () => onSelectPrompt(prompt),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primaryGreen : context.cardBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            border: isUser ? null : Border.all(color: context.borderColor),
          ),
          child: isUser
              ? Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
                  ),
                )
              : FormattedAiText(
                  text: message.text,
                  baseStyle: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Renders lightweight markdown (`**bold**`, `*italic*`, `` `code` ``, headings,
/// and bullet lists) into styled [TextSpan]s without raw `**` markers.
class FormattedAiText extends StatelessWidget {
  const FormattedAiText({
    super.key,
    required this.text,
    required this.baseStyle,
  });

  final String text;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final lines = text.trim().split('\n');
    final children = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final rawLine = lines[i].trimRight();
      final trimmed = rawLine.trimLeft();

      if (trimmed.isEmpty) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 6));
        }
        continue;
      }

      if (trimmed.startsWith('### ') ||
          trimmed.startsWith('## ') ||
          trimmed.startsWith('# ')) {
        final headingText = trimmed.replaceFirst(RegExp(r'^#{1,3}\s+'), '');
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 6, bottom: 2),
            child: Text.rich(
              TextSpan(
                children: _parseInline(
                  headingText,
                  baseStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final bulletMatch = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)!;
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: baseStyle.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: _parseInline(content, baseStyle)),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(
            TextSpan(children: _parseInline(trimmed, baseStyle)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static List<InlineSpan> _parseInline(String input, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)');
    var cursor = 0;

    for (final match in pattern.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: input.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }

      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('*') && token.endsWith('*')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (token.startsWith('`') && token.endsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor), style: baseStyle));
    }

    return spans;
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.borderColor),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
