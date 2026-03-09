import 'package:flutter/material.dart';

import 'alibaba_marketplace_tokens.dart';

class AlibabaSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const AlibabaSectionHeader({
    super.key,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AlibabaMarketplaceTokens.sectionTitleStyle(context),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.arrow_forward,
            color: AlibabaMarketplaceTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}
