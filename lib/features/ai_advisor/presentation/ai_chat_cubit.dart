import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money_formatter.dart';
import '../../expenses/presentation/expense_cubit.dart';
import '../data/gemini_chat_service.dart';

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isSending = false,
    this.errorMessage,
    this.briefText,
    this.briefMonthKey,
    this.briefLanguageCode,
    this.isLoadingBrief = false,
    this.briefError,
    required this.isConfigured,
    required this.modelName,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final String? errorMessage;
  final String? briefText;
  final String? briefMonthKey;
  final String? briefLanguageCode;
  final bool isLoadingBrief;
  final String? briefError;
  final bool isConfigured;
  final String modelName;

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
    String? briefText,
    String? briefMonthKey,
    String? briefLanguageCode,
    bool? isLoadingBrief,
    String? briefError,
    bool clearBriefError = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      briefText: briefText ?? this.briefText,
      briefMonthKey: briefMonthKey ?? this.briefMonthKey,
      briefLanguageCode: briefLanguageCode ?? this.briefLanguageCode,
      isLoadingBrief: isLoadingBrief ?? this.isLoadingBrief,
      briefError: clearBriefError ? null : (briefError ?? this.briefError),
      isConfigured: isConfigured,
      modelName: modelName,
    );
  }
}

class AiChatCubit extends Cubit<AiChatState> {
  AiChatCubit({required GeminiChatService service})
    : _service = service,
      super(
        AiChatState(
          isConfigured: service.isConfigured,
          modelName: service.modelName,
        ),
      );

  final GeminiChatService _service;

  Future<void> sendMessage(
    String rawText, {
    required ExpenseState expenseState,
    String languageCode = 'en',
  }) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isSending) return;

    final userMessage = ChatMessage(
      isUser: true,
      text: text,
      timestamp: DateTime.now(),
    );
    final updatedHistory = [...state.messages, userMessage];

    emit(
      state.copyWith(
        messages: updatedHistory,
        isSending: true,
        clearError: true,
      ),
    );

    try {
      final reply = await _service.sendMessage(
        history: updatedHistory,
        systemContext: _buildSystemContext(
          expenseState,
          languageCode: languageCode,
        ),
      );
      if (isClosed) return;

      final modelMessage = ChatMessage(
        isUser: false,
        text: reply,
        timestamp: DateTime.now(),
      );
      emit(
        state.copyWith(
          messages: [...updatedHistory, modelMessage],
          isSending: false,
        ),
      );
    } on GeminiFailure catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isSending: false, errorMessage: e.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSending: false,
          errorMessage: 'Failed to get AI advice. Please try again.',
        ),
      );
    }
  }

  void clearChat() {
    emit(state.copyWith(messages: const [], clearError: true));
  }

  /// Generates a concise AI spending brief and 2 tips for [expenseState].
  Future<void> generateMonthlyBrief(
    ExpenseState expenseState, {
    String languageCode = 'en',
    bool forceRefresh = false,
  }) async {
    if (!state.isConfigured || state.isLoadingBrief) return;
    final monthKey = expenseState.selectedMonthKey;
    if (!forceRefresh &&
        state.briefText != null &&
        state.briefMonthKey == monthKey &&
        state.briefLanguageCode == languageCode) {
      return;
    }
    if (expenseState.monthlyExpenses.isEmpty) {
      emit(
        state.copyWith(
          briefText: languageCode == 'ar'
              ? 'أضف بعض المصاريف هذا الشهر للحصول على **ملخص الإنفاق الذكي** ونصائح مخصصة.'
              : 'Add a few expenses this month to get your **AI spending brief** and personalized tips.',
          briefMonthKey: monthKey,
          briefLanguageCode: languageCode,
          clearBriefError: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isLoadingBrief: true,
        briefMonthKey: monthKey,
        briefLanguageCode: languageCode,
        clearBriefError: true,
      ),
    );

    try {
      final prompt = languageCode == 'ar'
          ? 'قدّم ملخصاً موجزاً من جملتين لإنفاقي هذا الشهر ونصيحتين عمليتين قصيرتين في نقاط.'
          : 'Give me a brief 2-sentence summary of my spending this month and 2 short actionable bullet-point tips.';
      final reply = await _service.sendMessage(
        history: [
          ChatMessage(isUser: true, text: prompt, timestamp: DateTime.now()),
        ],
        systemContext: _buildSystemContext(
          expenseState,
          languageCode: languageCode,
        ),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          briefText: reply,
          briefMonthKey: monthKey,
          briefLanguageCode: languageCode,
          isLoadingBrief: false,
        ),
      );
    } on GeminiFailure catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoadingBrief: false, briefError: e.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingBrief: false,
          briefError: 'Could not generate AI brief.',
        ),
      );
    }
  }

  String _buildSystemContext(
    ExpenseState expenseState, {
    String languageCode = 'en',
  }) {
    final monthLabel = DateFormat.yMMMM().format(expenseState.selectedMonth);
    final total = MoneyFormatter.formatEgp(expenseState.monthlyTotalMinor);
    final budget = expenseState.budgetLimitMinor != null
        ? MoneyFormatter.formatEgp(expenseState.budgetLimitMinor!)
        : 'Not set';
    final remaining = expenseState.remainingBudgetMinor != null
        ? MoneyFormatter.formatEgp(expenseState.remainingBudgetMinor!)
        : 'N/A';

    final categoriesBuffer = StringBuffer();
    final sortedCats = expenseState.categoryTotalsMinor.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedCats) {
      categoriesBuffer.writeln(
        '- ${entry.key.label}: ${MoneyFormatter.formatEgp(entry.value)}',
      );
    }

    final recentBuffer = StringBuffer();
    for (final e in expenseState.monthlyExpenses.take(10)) {
      recentBuffer.writeln(
        '- ${DateFormat.MMMd().format(e.date)} | ${e.title} (${e.category.label}): ${MoneyFormatter.formatEgp(e.amountMinor)}',
      );
    }

    final languageRule = languageCode == 'ar'
        ? 'IMPORTANT: Respond entirely in natural, clear Arabic (العربية) and use ج.م for EGP amounts.'
        : 'Respond in clear English.';

    return '''
You are Spendi AI, a concise, practical personal finance advisor for an expense tracker app in Egypt (currency: EGP).
$languageRule
Give clear, actionable, friendly budgeting and spending advice based on the user's real data below.
Format responses cleanly: start with a 1-2 sentence takeaway, then use short bullet points (`- `) with **bolded** key figures or categories. Keep total length concise.

User financial snapshot for $monthLabel:
- Total spent: $total
- Monthly budget: $budget
- Remaining budget: $remaining
- Expense count this month: ${expenseState.monthlyExpenses.length}

Spending by category:
${categoriesBuffer.isEmpty ? '- No expenses recorded yet.' : categoriesBuffer.toString()}

Recent expenses:
${recentBuffer.isEmpty ? '- None yet.' : recentBuffer.toString()}
''';
  }
}
