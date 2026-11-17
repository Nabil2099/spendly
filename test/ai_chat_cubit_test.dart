import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/features/ai_advisor/data/gemini_chat_service.dart';
import 'package:spendly/features/ai_advisor/presentation/ai_advisor_screen.dart';
import 'package:spendly/features/ai_advisor/presentation/ai_chat_cubit.dart';
import 'package:spendly/features/expenses/presentation/expense_cubit.dart';

class FakeGeminiChatService implements GeminiChatService {
  FakeGeminiChatService({this.configured = true, this.reply = 'Save more!'});

  final bool configured;
  final String reply;
  String? capturedContext;

  @override
  bool get isConfigured => configured;

  @override
  String get modelName => HttpGeminiChatService.defaultModel;

  @override
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String systemContext,
  }) async {
    capturedContext = systemContext;
    if (!configured) {
      throw const GeminiFailure('Gemini API key is missing.');
    }
    return reply;
  }
}

void main() {
  test(
    'AiChatCubit defaults to gemini-3.5-flash-lite and appends reply',
    () async {
      final service = FakeGeminiChatService(
        reply: 'You spent EGP 0.00 so far this month.',
      );
      final cubit = AiChatCubit(service: service);
      addTearDown(cubit.close);

      expect(cubit.state.modelName, 'gemini-3.5-flash-lite');
      expect(cubit.state.isConfigured, isTrue);

      await cubit.sendMessage(
        'How is my budget?',
        expenseState: ExpenseState(selectedMonth: DateTime(2026, 11, 1)),
      );

      expect(cubit.state.messages.length, 2);
      expect(cubit.state.messages.first.isUser, isTrue);
      expect(cubit.state.messages.last.isUser, isFalse);
      expect(cubit.state.messages.last.text, contains('EGP 0.00'));
      expect(service.capturedContext, contains('November 2026'));
    },
  );

  testWidgets('FormattedAiText renders bold text without raw ** markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedAiText(
            text: '- You spent **EGP 450.00** on **Food**.',
            baseStyle: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.textContaining('**'), findsNothing);
    expect(
      find.textContaining('EGP 450.00', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Food', findRichText: true), findsOneWidget);
  });

  testWidgets('FormattedAiText renders bold text without raw ** markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedAiText(
            text: '- You spent **EGP 450.00** on **Food**.',
            baseStyle: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(find.textContaining('**'), findsNothing);
    expect(
      find.textContaining('EGP 450.00', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Food', findRichText: true), findsOneWidget);
  });
}
