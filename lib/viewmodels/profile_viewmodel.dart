import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../models/api_models.dart';
import '../models/reward_models.dart';
import '../repositories/badge_repository.dart';
import '../repositories/reward_repository.dart';
import '../repositories/user_repository.dart';
import 'view_state.dart';

class ProfileViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  String? _errorMessage;
  AppUser? _user;
  UserStats? _stats;
  List<UserBadge> _badges = [];
  RewardSummary? _rewards;
  List<RewardTask> _rewardTasks = [];
  bool _disposed = false;

  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  AppUser? get user => _user;
  UserStats? get stats => _stats;
  List<UserBadge> get badges => _badges;
  RewardSummary? get rewards => _rewards;
  List<RewardTask> get rewardTasks => _rewardTasks;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await UserRepository.getUser(AppState.userId);
      _stats = await UserRepository.getUserStats(AppState.userId);
      _badges = await BadgeRepository.getUserBadges(AppState.userId);
      _rewards = await RewardRepository.getMyRewards();
      _rewardTasks = await RewardRepository.getMyTasks();
      _state = ViewState.idle;
    } catch (_) {
      _state = ViewState.error;
      _errorMessage = 'Failed to load profile.';
    }
    if (!_disposed) notifyListeners();
  }

  String? _updateError;
  String? get updateError => _updateError;

  /// Updates editable student profile fields via PATCH /users/me/profile.
  /// Returns true on success. On failure keeps the view intact and returns false.
  /// Does NOT set ViewState.error — that would replace the whole profile view.
  Future<bool> updateProfile({
    String? name,
    String? className,
    String? schoolName,
    String? location,
    int? age,
    DateTime? dateOfBirth,
    String? parentEmail,
    String? phone,
  }) async {
    _updateError = null;
    notifyListeners();
    try {
      final updated = await UserRepository.updateProfile(
        name: name,
        className: className,
        schoolName: schoolName,
        location: location,
        age: age,
        dateOfBirth: dateOfBirth,
        parentEmail: parentEmail,
        phone: phone,
      );
      _user = updated;
      if (name != null) AppState.studentName = name;
      if (!_disposed) notifyListeners();
      return true;
    } catch (_) {
      _updateError = 'Failed to update profile. Please try again.';
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  Future<void> advanceRewardTask(int taskId) async {
    try {
      final updated = await RewardRepository.advanceTask(taskId);
      final idx = _rewardTasks.indexWhere((task) => task.id == taskId);
      if (idx != -1) {
        _rewardTasks[idx] = updated;
      }
      _rewards = await RewardRepository.getMyRewards();
      if (!_disposed) notifyListeners();
    } catch (_) {}
  }
}
