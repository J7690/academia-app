import 'package:flutter/material.dart';

import 'alibaba_marketplace_tokens.dart';

class AlibabaSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSearch;
  final VoidCallback? onCamera;
  final VoidCallback? onMic;
  final String hintText;

  const AlibabaSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSearch,
    this.onCamera,
    this.onMic,
    this.hintText = 'Rechercher…',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(AlibabaMarketplaceTokens.radiusSearch),
          border: Border.all(
            color: AlibabaMarketplaceTokens.primaryOrange,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onCamera,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.photo_camera_outlined,
                color: AlibabaMarketplaceTokens.textSecondary,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch?.call(),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: AlibabaMarketplaceTokens.textMeta,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(
                  color: AlibabaMarketplaceTokens.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              onPressed: onMic,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.mic_none,
                color: AlibabaMarketplaceTokens.textSecondary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
              child: SizedBox(
                width: 42,
                child: Material(
                  color: AlibabaMarketplaceTokens.primaryOrange,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onSearch,
                    borderRadius: BorderRadius.circular(10),
                    child: const Center(
                      child: Icon(
                        Icons.search,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
