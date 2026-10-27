import 'package:flutter/material.dart';

import 'alibaba_marketplace_tokens.dart';

class AlibabaSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSearch;
  final VoidCallback? onCamera;
  final VoidCallback? onMic;
  final VoidCallback? onFilters;
  final int activeFilters;
  final String hintText;

  const AlibabaSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSearch,
    this.onCamera,
    this.onMic,
    this.onFilters,
    this.activeFilters = 0,
    this.hintText = 'Rechercher un produit, un vendeur…',
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AlibabaMarketplaceTokens.radiusSearch);
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: r,
          boxShadow: AlibabaMarketplaceTokens.shadowSoft,
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, color: AlibabaMarketplaceTokens.brand, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch?.call(),
                cursorColor: AlibabaMarketplaceTokens.brand,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: AlibabaMarketplaceTokens.textMeta,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                style: const TextStyle(
                  color: AlibabaMarketplaceTokens.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, v, _) {
                return AnimatedSwitcher(
                  duration: AlibabaMarketplaceTokens.fast,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: v.text.isEmpty
                      ? const SizedBox(key: ValueKey('e'), width: 4)
                      : IconButton(
                          key: const ValueKey('c'),
                          tooltip: 'Effacer',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            controller.clear();
                            onChanged?.call('');
                          },
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AlibabaMarketplaceTokens.textMeta),
                        ),
                );
              },
            ),
            if (onCamera != null)
              IconButton(
                onPressed: onCamera,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.photo_camera_outlined, color: AlibabaMarketplaceTokens.textSecondary),
              ),
            if (onMic != null)
              IconButton(
                onPressed: onMic,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.mic_none_rounded, color: AlibabaMarketplaceTokens.textSecondary),
              ),
            if (onFilters != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
                child: Material(
                  color: activeFilters > 0 ? AlibabaMarketplaceTokens.brand : AlibabaMarketplaceTokens.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onFilters,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: activeFilters > 0 ? Colors.white : AlibabaMarketplaceTokens.brand,
                          ),
                          if (activeFilters > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AlibabaMarketplaceTokens.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
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
