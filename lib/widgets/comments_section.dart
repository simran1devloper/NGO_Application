import 'package:flutter/material.dart';

import '../models/comment.dart';
import '../models/reaction.dart';
import '../repositories/comment_repository.dart';
import 'reaction_bar.dart';

/// Drop-in comment section for any post.
///
/// Usage:
/// ```dart
/// CommentsSection(postId: post.id)
/// ```
class CommentsSection extends StatefulWidget {
  const CommentsSection({
    super.key,
    required this.postId,
    this.currentUserId,
    this.currentUserName,
  });

  final int postId;
  final int? currentUserId;
  final String? currentUserName;

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _inputCtrl    = TextEditingController();
  final _inputFocus   = FocusNode();
  List<Comment> _comments  = [];
  bool _loading       = true;
  bool _posting       = false;
  int? _replyToId;
  String? _replyToName;
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await CommentRepository.listComments(widget.postId);
      if (mounted) setState(() => _comments = list);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);

    try {
      if (_editingId != null) {
        final updated = await CommentRepository.editComment(
          commentId: _editingId!,
          body: text,
        );
        _replaceComment(updated);
        _cancelEdit();
      } else {
        final newComment = await CommentRepository.postComment(
          postId: widget.postId,
          body: text,
          parentId: _replyToId,
        );
        if (_replyToId != null) {
          _insertReply(newComment);
        } else {
          setState(() => _comments = [newComment, ..._comments]);
        }
        _cancelReply();
      }
      _inputCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _insertReply(Comment reply) {
    setState(() {
      _comments = _comments.map((c) {
        if (c.id == _replyToId) {
          return Comment(
            id: c.id, postId: c.postId, userId: c.userId,
            parentId: c.parentId, body: c.body, isEdited: c.isEdited,
            isDeleted: c.isDeleted, isHidden: c.isHidden,
            moderationLabel: c.moderationLabel,
            createdAt: c.createdAt, updatedAt: c.updatedAt,
            user: c.user, replyCount: c.replyCount + 1,
            replies: [...c.replies, reply],
          );
        }
        return c;
      }).toList();
    });
  }

  void _replaceComment(Comment updated) {
    setState(() {
      _comments = _comments.map((c) {
        if (c.id == updated.id) return updated;
        final newReplies = c.replies.map((r) => r.id == updated.id ? updated : r).toList();
        return Comment(
          id: c.id, postId: c.postId, userId: c.userId,
          parentId: c.parentId, body: c.body, isEdited: c.isEdited,
          isDeleted: c.isDeleted, isHidden: c.isHidden,
          moderationLabel: c.moderationLabel,
          createdAt: c.createdAt, updatedAt: c.updatedAt,
          user: c.user, replyCount: c.replyCount, replies: newReplies,
        );
      }).toList();
    });
  }

  Future<void> _delete(int commentId) async {
    try {
      await CommentRepository.deleteComment(commentId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void _startReply(int commentId, String authorName) {
    setState(() {
      _replyToId   = commentId;
      _replyToName = authorName;
      _editingId   = null;
    });
    _inputCtrl.clear();
    _inputFocus.requestFocus();
  }

  void _startEdit(Comment c) {
    setState(() {
      _editingId   = c.id;
      _replyToId   = null;
      _replyToName = null;
    });
    _inputCtrl.text = c.body;
    _inputFocus.requestFocus();
  }

  void _cancelReply() => setState(() { _replyToId = null; _replyToName = null; });
  void _cancelEdit()  => setState(() { _editingId = null; _inputCtrl.clear(); });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.comment_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                '${_comments.fold(0, (s, c) => s + 1 + c.replies.length)} Comments',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Comments list ────────────────────────────────────────────────
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No comments yet. Be the first!',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            itemBuilder: (_, i) => _CommentTile(
              comment: _comments[i],
              currentUserId: widget.currentUserId,
              onReply: (id, name) => _startReply(id, name),
              onEdit: _startEdit,
              onDelete: _delete,
            ),
          ),

        const Divider(height: 1),

        // ── Input area ───────────────────────────────────────────────────
        if (_replyToName != null)
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 14, color: Colors.blue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Replying to $_replyToName',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: _cancelReply,
                  child: const Icon(Icons.close, size: 16, color: Colors.blue),
                ),
              ],
            ),
          ),
        if (_editingId != null)
          Container(
            color: Colors.orange.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.edit, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text('Editing comment',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                ),
                GestureDetector(
                  onTap: _cancelEdit,
                  child: const Icon(Icons.close, size: 16, color: Colors.orange),
                ),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  focusNode: _inputFocus,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _replyToName != null
                        ? 'Write a reply…'
                        : 'Write a comment…',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _posting
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton.filled(
                      onPressed: _submit,
                      icon: const Icon(Icons.send_rounded),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Comment tile ──────────────────────────────────────────────────────────────

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  final Comment comment;
  final int? currentUserId;
  final void Function(int id, String name) onReply;
  final void Function(Comment c) onEdit;
  final void Function(int id) onDelete;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _showReplies = false;

  bool get _isOwn => widget.currentUserId != null &&
      widget.comment.userId == widget.currentUserId;

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SingleComment(
          comment: c,
          isOwn: _isOwn,
          isReply: false,
          onReply: (c.isDeleted || c.isHidden)
              ? null
              : () => widget.onReply(c.id, c.user?.name ?? 'User'),
          onEdit: (c.isDeleted || c.isHidden)
              ? null
              : (_isOwn ? () => widget.onEdit(c) : null),
          onDelete: (!c.isHidden && _isOwn)
              ? () => widget.onDelete(c.id)
              : null,
        ),

        // Replies
        if (c.replies.isNotEmpty || c.replyCount > 0) ...[
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: TextButton.icon(
              onPressed: () => setState(() => _showReplies = !_showReplies),
              icon: Icon(
                _showReplies
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
              ),
              label: Text(
                _showReplies
                    ? 'Hide replies'
                    : '${c.replyCount > 0 ? c.replyCount : c.replies.length} repl${c.replyCount == 1 ? 'y' : 'ies'}',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: Colors.blue,
              ),
            ),
          ),
          if (_showReplies)
            ...c.replies.map((r) => Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: _SingleComment(
                    comment: r,
                    isOwn: widget.currentUserId == r.userId,
                    isReply: true,
                    onReply: (r.isDeleted || r.isHidden)
                        ? null
                        : () => widget.onReply(c.id, r.user?.name ?? 'User'),
                    onEdit: (r.isDeleted || r.isHidden)
                        ? null
                        : widget.currentUserId == r.userId
                            ? () => widget.onEdit(r)
                            : null,
                    onDelete: (!r.isHidden && widget.currentUserId == r.userId)
                        ? () => widget.onDelete(r.id)
                        : null,
                  ),
                )),
        ],

        const Divider(height: 1, indent: 16),
      ],
    );
  }
}

class _SingleComment extends StatelessWidget {
  const _SingleComment({
    required this.comment,
    required this.isOwn,
    required this.isReply,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  final Comment comment;
  final bool isOwn;
  final bool isReply;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isHidden  = comment.isHidden;
    final isDeleted = comment.isDeleted;
    // When hidden, the author is still shown (transparency) but the body and
    // interaction controls are suppressed. The mediator's identity is never shown.
    final name     = comment.user?.name ?? 'User';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.fromLTRB(isReply ? 0 : 12, 10, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar — grey when deleted/hidden
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundColor: (isDeleted || isHidden)
                ? Colors.grey.shade200
                : Colors.deepPurple.shade100,
            child: Text(
              isDeleted ? '?' : initials,
              style: TextStyle(
                fontSize: isReply ? 11 : 14,
                fontWeight: FontWeight.bold,
                color: (isDeleted || isHidden)
                    ? Colors.grey
                    : Colors.deepPurple,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Author row ──────────────────────────────────────────────
                Row(
                  children: [
                    Text(
                      isDeleted ? '[deleted]' : name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isReply ? 12 : 13,
                        color: (isDeleted || isHidden) ? Colors.grey : null,
                      ),
                    ),
                    if (isOwn && !isDeleted && !isHidden) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                    // Moderation badge — visible to everyone; no actor named
                    if (isHidden) ...[
                      const SizedBox(width: 6),
                      _ModerationBadge(),
                    ],
                    const Spacer(),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    // Popup menu: only shown on non-hidden, non-deleted comments
                    if (!isHidden && !isDeleted &&
                        (onEdit != null || onDelete != null))
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        onSelected: (v) {
                          if (v == 'edit')   onEdit?.call();
                          if (v == 'delete') onDelete?.call();
                        },
                        itemBuilder: (_) => [
                          if (onEdit != null)
                            const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit, size: 14),
                                  SizedBox(width: 6),
                                  Text('Edit'),
                                ])),
                          if (onDelete != null)
                            const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline,
                                      size: 14, color: Colors.red),
                                  SizedBox(width: 6),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ])),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 3),

                // ── Body ───────────────────────────────────────────────────
                if (isHidden)
                  // Transparent notice that moderation happened — actor hidden
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(
                          color: Colors.orange.shade200, width: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 13, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            comment.moderationLabel ??
                                'This comment was removed by the moderation team.',
                            style: TextStyle(
                              fontSize: isReply ? 11 : 12,
                              color: Colors.orange.shade800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    isDeleted ? 'This comment has been deleted.' : comment.body,
                    style: TextStyle(
                      fontSize: isReply ? 12 : 13,
                      color: isDeleted ? Colors.grey : null,
                      fontStyle:
                          isDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),

                if (comment.isEdited && !isDeleted && !isHidden)
                  const Text('(edited)',
                      style: TextStyle(fontSize: 10, color: Colors.grey)),

                // ── Reactions + Reply — suppressed when hidden or deleted ──
                if (!isDeleted && !isHidden) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ReactionBar(
                        targetType: TargetType.comment,
                        targetId:   comment.id,
                        showLikeDislike: true,
                        compact: true,
                      ),
                      if (onReply != null) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: onReply,
                          child: const Text(
                            'Reply',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Moderation badge — shows that moderation happened, never who did it ───────

class _ModerationBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade300, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 9, color: Colors.orange.shade700),
          const SizedBox(width: 3),
          Text(
            'moderated',
            style: TextStyle(
              fontSize: 9,
              color: Colors.orange.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
