import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const Color _backgroundColor = Color(0xFFF6F7FB);
  static const Color _textColor = Color(0xFF14161F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'More',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: const <Widget>[
            _MoreSection(
              title: 'Category',
              items: <_MoreItemData>[
                _MoreItemData(title: 'Import Category Setting'),
                _MoreItemData(title: 'Expense Category Setting'),
              ],
            ),
            SizedBox(height: 14),
            _MoreSection(
              title: 'Setting',
              items: <_MoreItemData>[
                _MoreItemData(title: 'Currency Setting'),
                _MoreItemData(title: 'Transaction Setting'),
                _MoreItemData(title: 'Style', subtitle: 'Dark, Light'),
                _MoreItemData(title: 'Language Setting'),
              ],
            ),
            SizedBox(height: 14),
            _MoreSection(
              title: 'Help',
              items: <_MoreItemData>[
                _MoreItemData(title: 'Help'),
                _MoreItemData(title: 'FeedBack'),
                _MoreItemData(title: 'Rate Us'),
                _MoreItemData(title: 'Remove Ad'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.title, required this.items});

  final String title;
  final List<_MoreItemData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _MoreScreenStateColors.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _MoreScreenStateColors.softBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _MoreScreenStateColors.textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _MoreItem(item: item)),
        ],
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem({required this.item});

  final _MoreItemData item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _MoreScreenStateColors.textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: item.subtitle == null
          ? null
          : Text(
              item.subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _MoreScreenStateColors.mutedTextColor,
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: _MoreScreenStateColors.mutedTextColor,
      ),
    );
  }
}

class _MoreItemData {
  const _MoreItemData({required this.title, this.subtitle});

  final String title;
  final String? subtitle;
}

class _MoreScreenStateColors {
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF14161F);
  static const Color mutedTextColor = Color(0xFF8B90A0);
  static const Color softBorderColor = Color(0xFFE9EBF2);
}
