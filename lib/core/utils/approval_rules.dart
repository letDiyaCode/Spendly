import 'dart:math' as math;

import '../models/enums.dart';
import '../models/expense.dart';
import '../models/group.dart';

int requiredApprovalsForGroup(Group? group) {
  if (group == null) {
    return 1;
  }

  return math.max(1, (group.memberIds.length * 0.6).ceil());
}

bool isGroupExpenseApproved(Expense expense, Group? group) {
  if (expense.type != ExpenseType.group) {
    return true;
  }

  if (group == null) {
    return true;
  }

  return expense.approvals.length >= requiredApprovalsForGroup(group);
}
