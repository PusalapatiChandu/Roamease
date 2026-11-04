import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import 'notification_settings_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.network:
        return Icons.cell_tower_rounded;
      case NotificationCategory.roaming:
        return Icons.public_rounded;
      case NotificationCategory.location:
        return Icons.my_location_rounded;
      case NotificationCategory.dataUsage:
        return Icons.data_usage_rounded;
      case NotificationCategory.security:
        return Icons.security_rounded;
      case NotificationCategory.general:
        return Icons.notifications_rounded;
    }
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.network:
        return AppColors.cyan5G;
      case NotificationCategory.roaming:
        return AppColors.roamingWarning;
      case NotificationCategory.location:
        return AppColors.signalExcellent;
      case NotificationCategory.dataUsage:
        return AppColors.royalBlue;
      case NotificationCategory.security:
        return AppColors.signalPoor;
      case NotificationCategory.general:
        return AppColors.primaryBlue;
    }
  }

  String _getCategoryLabel(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.network:
        return 'NETWORK';
      case NotificationCategory.roaming:
        return 'ROAMING';
      case NotificationCategory.location:
        return 'LOCATION';
      case NotificationCategory.dataUsage:
        return 'DATA USAGE';
      case NotificationCategory.security:
        return 'SECURITY';
      case NotificationCategory.general:
        return 'SYSTEM';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifProvider = Provider.of<NotificationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final userId = authProvider.currentSubscriber?.uid ?? 'guest';
    final notifications = notifProvider.notifications;
    final unreadCount = notifProvider.unreadCount;
    final currentFilter = notifProvider.currentFilter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (notifProvider.allNotifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Mark All as Read',
              onPressed: () {
                notifProvider.markAllAsRead(userId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All alerts marked as read.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear All Notifications',
              onPressed: () => _confirmClearAll(context, notifProvider, userId),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification Preferences',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // 1. Unread & Notification Summary Banner
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cyan5G,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You have $unreadCount unread notification${unreadCount == 1 ? "" : "s"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => notifProvider.markAllAsRead(userId),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Mark Read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // 2. Horizontal Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(context, label: 'All', filterKey: 'all', currentFilter: currentFilter, notifProvider: notifProvider),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: 'Unread',
                  filterKey: 'unread',
                  currentFilter: currentFilter,
                  notifProvider: notifProvider,
                  badgeCount: unreadCount,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(context, label: 'Network', filterKey: 'network', currentFilter: currentFilter, notifProvider: notifProvider),
                const SizedBox(width: 8),
                _buildFilterChip(context, label: 'Roaming', filterKey: 'roaming', currentFilter: currentFilter, notifProvider: notifProvider),
                const SizedBox(width: 8),
                _buildFilterChip(context, label: 'Location', filterKey: 'location', currentFilter: currentFilter, notifProvider: notifProvider),
                const SizedBox(width: 8),
                _buildFilterChip(context, label: 'Data', filterKey: 'dataUsage', currentFilter: currentFilter, notifProvider: notifProvider),
                const SizedBox(width: 8),
                _buildFilterChip(context, label: 'Security', filterKey: 'security', currentFilter: currentFilter, notifProvider: notifProvider),
              ],
            ),
          ),

          const Divider(height: 1),

          // 3. Notification List or Empty State
          Expanded(
            child: notifications.isEmpty
                ? _buildEmptyState(context, isDark, currentFilter)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return _buildNotificationCard(
                        context: context,
                        item: item,
                        isDark: isDark,
                        notifProvider: notifProvider,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required String filterKey,
    required String currentFilter,
    required NotificationProvider notifProvider,
    int? badgeCount,
  }) {
    final isSelected = currentFilter == filterKey;

    return ChoiceChip(
      selected: isSelected,
      selectedColor: AppColors.primaryBlue,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badgeCount != null && badgeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : AppColors.cyan5G,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.navyDark : Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => notifProvider.setFilter(filterKey),
    );
  }

  Widget _buildNotificationCard({
    required BuildContext context,
    required NotificationModel item,
    required bool isDark,
    required NotificationProvider notifProvider,
  }) {
    final color = _getCategoryColor(item.category);
    final icon = _getCategoryIcon(item.category);
    final categoryLabel = _getCategoryLabel(item.category);
    final timeStr = _formatRelativeTime(item.timestamp);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.signalPoor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        notifProvider.deleteNotification(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification removed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !item.isRead
                ? AppColors.primaryBlue.withOpacity(0.5)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: !item.isRead ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (!item.isRead)
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Toggle read status on tap
            if (!item.isRead) {
              notifProvider.markAsRead(item.id);
            } else {
              notifProvider.markAsUnread(item.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),

                // Notification Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Category Badge + Relative Time + Unread Dot
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                              if (!item.isRead) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: !item.isRead ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                          color: isDark ? Colors.white : AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Body Message
                      Text(
                        item.body,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                // Popup Options Menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                  padding: EdgeInsets.zero,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: item.isRead ? 'unread' : 'read',
                      child: Row(
                        children: [
                          Icon(item.isRead ? Icons.mark_email_unread_rounded : Icons.drafts_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(item.isRead ? 'Mark as Unread' : 'Mark as Read', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.signalPoor),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(fontSize: 12, color: AppColors.signalPoor)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (val) {
                    if (val == 'read') {
                      notifProvider.markAsRead(item.id);
                    } else if (val == 'unread') {
                      notifProvider.markAsUnread(item.id);
                    } else if (val == 'delete') {
                      notifProvider.deleteNotification(item.id);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, String currentFilter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 16),
          Text(
            currentFilter == 'unread'
                ? 'No Unread Notifications'
                : 'No Notifications in this Category',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Live alerts for 4G/5G transitions, roaming,\nand data limits will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, NotificationProvider notifProvider, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications?'),
        content: const Text('This will delete all notification records from your device and Cloud Firestore.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              notifProvider.clearAll(userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.signalPoor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
