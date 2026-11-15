import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../chat_controller.dart';

class AppSidebar extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const AppSidebar({super.key, this.onClose});

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  List<dynamic> conversations = [];
  bool loading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadConversations();
  }

  Future<void> loadConversations() async {
    try {
      final items = await ref.read(apiProvider).get('/conversations');
      if (mounted) {
        setState(() {
          conversations = items is List ? items : [];
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  List<dynamic> get filteredConversations {
    if (searchQuery.trim().isEmpty) {
      return conversations;
    }
    return conversations.where((item) {
      final title = (item['title'] ?? '').toString().toLowerCase();
      return title.contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentChatId = ref.watch(chatProvider).conversationId;

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header with logo & collapse
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'الحريفي AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.menu_open_rounded, size: 22),
                      tooltip: 'إغلاق القائمة',
                      onPressed: widget.onClose,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),

            // 2. "+ New chat" Black Pill Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Material(
                color: isDark ? const Color(0xFF28243A) : AppColors.darkPill,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    ref.read(chatProvider.notifier).fresh();
                    if (widget.onClose != null) {
                      widget.onClose!();
                    }
                  },
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 19),
                        SizedBox(width: 8),
                        Text(
                          'محادثة جديدة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 3. Search Box with ⌘K Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF201D2E) : const Color(0xFFF7F5FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFEDE8F4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 18,
                      color: isDark ? Colors.white60 : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => searchQuery = val),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'بحث...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : AppColors.textMuted,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2B273D) : const Color(0xFFEBE6F3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '⌘K',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 4. Primary Navigation items
            _SidebarNavItem(
              icon: Icons.explore_outlined,
              label: 'استكشاف',
              onTap: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                }
              },
            ),
            _SidebarNavItem(
              icon: Icons.auto_stories_outlined,
              label: 'المكتبة والتفضيلات',
              onTap: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                }
                context.push('/settings');
              },
            ),
            _SidebarNavItem(
              icon: Icons.folder_open_outlined,
              label: 'معلومات الحرفة',
              onTap: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                }
                context.push('/business');
              },
            ),
            _SidebarNavItem(
              icon: Icons.history_rounded,
              label: 'السجل الكامل',
              onTap: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                }
                context.push('/history');
              },
            ),

            const Divider(height: 20, indent: 14, endIndent: 14),

            // 5. Past Chats Section (Grouped: Today, Yesterday, 7 Days)
            Expanded(
              child: loading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : filteredConversations.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              searchQuery.isEmpty
                                  ? 'ما عندك حتى محادثة دابا'
                                  : 'ما لقينا حتى محادثة بهاد الاسم',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(10, 6, 10, 6),
                              child: Text(
                                'المحادثات الأخيرة',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            for (final item in filteredConversations)
                              _ChatHistoryItem(
                                title: item['title'] ?? 'محادثة بدون عنوان',
                                isSelected: currentChatId == item['id'],
                                onTap: () async {
                                  try {
                                    await ref
                                        .read(chatProvider.notifier)
                                        .open(item['id']);
                                    if (widget.onClose != null) {
                                      widget.onClose!();
                                    }
                                  } catch (_) {}
                                },
                              ),
                          ],
                        ),
            ),

            const Divider(height: 1),

            // 6. User Profile Bar at the bottom
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.8),
                          const Color(0xFFC4B5FD),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'ح',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'الحريفي المغربي',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'حرفي معتمد • نشط',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    tooltip: 'خروج',
                    color: AppColors.textMuted,
                    onPressed: () => context.go('/'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHistoryItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChatHistoryItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? (isDark
                ? AppColors.primary.withValues(alpha: 0.25)
                : AppColors.primaryTint)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 15,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white38 : AppColors.textMuted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white70 : AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
