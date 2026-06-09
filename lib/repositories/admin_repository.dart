import '../models/api_models.dart';
import 'api_client.dart';

class AdminRepository {
  const AdminRepository._();

  // ── User statistics ───────────────────────────────────────────────────────

  static Future<AdminStats> getStats() async {
    try {
      final json =
          await ApiClient.get('/admin/stats') as Map<String, dynamic>;
      return AdminStats.fromJson(json);
    } catch (_) {
      return AdminStats.empty();
    }
  }

  // ── All users ─────────────────────────────────────────────────────────────

  /// GET /admin/users — returns all users with optional filters.
  static Future<List<AdminUserItem>> getAllUsers({
    String? search,
    String? role,
    String? status,
  }) async {
    final params = <String, String>{
      if (search != null && search.isNotEmpty) 'search': search,
      if (role != null && role.isNotEmpty) 'role': role,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final list =
        await ApiClient.get('/admin/users$query') as List<dynamic>;
    return list
        .map((e) => AdminUserItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /admin/users/{id}/block
  static Future<void> blockUser(int userId, {String? reason}) async {
    await ApiClient.patch('/admin/users/$userId/block', {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  /// PATCH /admin/users/{id}/unblock
  static Future<void> unblockUser(int userId) async {
    await ApiClient.patch('/admin/users/$userId/unblock', {});
  }

  /// DELETE /admin/users/{id}
  static Future<void> deleteUser(int userId) async {
    await ApiClient.delete('/admin/users/$userId');
  }

  // ── Pending approvals ─────────────────────────────────────────────────────

  static Future<List<PendingUserItem>> getPendingUsers() async {
    final list = await ApiClient.get('/admin/users/pending') as List<dynamic>;
    return list
        .map((e) => PendingUserItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /admin/users/{id}/assign-role
  /// Only admin/super_admin may call this.
  /// role must be one of: student, mentor, content_creator.
  /// Only super_admin may assign the 'admin' role.
  static Future<Map<String, dynamic>> assignRole({
    required int userId,
    required String role,
    String accessStatus = 'approved',
    String? verificationNote,
  }) async {
    return await ApiClient.patch('/admin/users/$userId/assign-role', {
      'role': role,
      'access_status': accessStatus,
      if (verificationNote != null && verificationNote.isNotEmpty)
        'verification_note': verificationNote,
    }) as Map<String, dynamic>;
  }

  /// PATCH /admin/users/{id}/set-roles
  /// Saves every feature/admin role a user holds. The backend computes the
  /// primary role from this list.
  static Future<Map<String, dynamic>> setRoles({
    required int userId,
    required List<String> roles,
    String accessStatus = 'approved',
    String? verificationNote,
  }) async {
    return await ApiClient.patch('/admin/users/$userId/set-roles', {
      'roles': roles,
      'access_status': accessStatus,
      if (verificationNote != null && verificationNote.isNotEmpty)
        'verification_note': verificationNote,
    }) as Map<String, dynamic>;
  }

  /// PATCH /admin/users/{id}/reject
  static Future<void> rejectUser(int userId, {String? reason}) async {
    await ApiClient.patch('/admin/users/$userId/reject', {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  /// PATCH /admin/users/{id}/deactivate
  static Future<void> deactivateUser(int userId) async {
    await ApiClient.patch('/admin/users/$userId/deactivate', {});
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  static Future<List<AdminNotification>> getNotifications() async {
    final list =
        await ApiClient.get('/admin/notifications') as List<dynamic>;
    return list
        .map((e) => AdminNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> markNotificationRead(int notificationId) async {
    await ApiClient.patch(
      '/admin/notifications/$notificationId/read',
      {},
    );
  }

  static Future<void> markAllNotificationsRead() async {
    await ApiClient.patch('/admin/notifications/read-all', {});
  }

  // ── Bulk operations ───────────────────────────────────────────────────────

  /// POST /admin/users/bulk-approve
  static Future<Map<String, dynamic>> bulkApprove({
    required List<int> userIds,
    required String role,
    String accessStatus = 'approved',
    String? verificationNote,
  }) async {
    return await ApiClient.post('/admin/users/bulk-approve', {
      'user_ids': userIds,
      'role': role,
      'access_status': accessStatus,
      if (verificationNote != null && verificationNote.isNotEmpty)
        'verification_note': verificationNote,
    }) as Map<String, dynamic>;
  }

  /// POST /admin/users/bulk-delete
  static Future<Map<String, dynamic>> bulkDelete(List<int> userIds) async {
    return await ApiClient.post('/admin/users/bulk-delete', {'user_ids': userIds})
        as Map<String, dynamic>;
  }

  // ── User detail ───────────────────────────────────────────────────────────

  static Future<AppUser> getUserDetail(int userId) async {
    final json =
        await ApiClient.get('/admin/users/$userId') as Map<String, dynamic>;
    return AppUser.fromJson(json);
  }
}
