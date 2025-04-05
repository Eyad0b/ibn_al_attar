import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ibn_al_attar/core/constants/app_colors.dart';
import 'package:ibn_al_attar/core/constants/app_strings.dart';
import 'package:ibn_al_attar/core/utils/helpers.dart';

class ResponsiveStorageCard extends StatelessWidget {
  final Map<String, dynamic> storage;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onEnterStorage;

  const ResponsiveStorageCard({
    super.key,
    required this.storage,
    required this.onDelete,
    required this.onEdit,
    required this.onEnterStorage,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final itemCount = (storage['rows'] as List?)?.length ?? 0;
    final updatedAt = storage['updatedAt'] is Timestamp
        ? (storage['updatedAt'] as Timestamp).toDate()
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // transform: Matrix4.identity()..scale(hover ? 1.02 : 1.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onEnterStorage,
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 10 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.storage,
                          size: isMobile ? 16 : 32,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          storage['name'] ?? AppStrings.unnamedStorage,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isMobile ? 14 : 22,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.inventory_2,
                        label:
                            '$itemCount ${itemCount == 1 ? 'Item' : 'Items'}',
                        isMobile: isMobile,
                      ),
                      if (updatedAt != null)
                        _InfoChip(
                          icon: Icons.update,
                          label: Helpers.formatDate(updatedAt,
                              format: 'MMM d, yyyy'),
                          isMobile: isMobile,
                        ),
                    ],
                  ),
                  const Spacer(),
                  _ActionBar(
                    onDelete: onDelete,
                    onEdit: onEdit,
                    onEnter: onEnterStorage,
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isMobile;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: isMobile ? 10 : 20),
      label: Text(
        label,
        style: TextStyle(fontSize: isMobile ? 10 : 14),
      ),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.background,
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onEnter;
  final bool isMobile;

  const _ActionBar({
    required this.onDelete,
    required this.onEdit,
    required this.onEnter,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(isMobile ? Icons.open_in_new : Icons.visibility),
          onPressed: onEnter,
          tooltip: 'View Details',
          iconSize: isMobile ? 16 : 24,
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
          tooltip: 'Edit Storage',
          iconSize: isMobile ? 16 : 24,
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onDelete,
          tooltip: 'Delete Storage',
          iconSize: isMobile ? 16 : 24,
          color: AppColors.error,
        ),
      ],
    );
  }
}
