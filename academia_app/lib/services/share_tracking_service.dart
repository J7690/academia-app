import 'package:supabase_flutter/supabase_flutter.dart';

class ShareTrackingService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String?> registerShare({
    required String studentId,
    required String promoterCommercialId,
    required String shareSource,
    required String sharedItemType,
    String? sharedItemId,
    String? sharedItemTitle,
    String? refCode,
    String? utmSource,
    String? utmMedium,
    String? utmCampaign,
    String? contentAssetId,
  }) async {
    try {
      final resp = await _client.rpc('app_register_share', params: {
        'p_student_id': studentId,
        'p_promoter_commercial_id': promoterCommercialId,
        'p_share_source': shareSource,
        'p_shared_item_type': sharedItemType,
        'p_shared_item_id': sharedItemId,
        'p_shared_item_title': sharedItemTitle,
        'p_ref_code': refCode,
        'p_utm_source': utmSource,
        'p_utm_medium': utmMedium,
        'p_utm_campaign': utmCampaign,
        'p_content_asset_id': contentAssetId,
      });
      if (resp is Map<String, dynamic> && resp['success'] == true) {
        return resp['share_id'] as String?;
      }
      return null;
    } catch (e) {
      print('Error registering share: $e');
      return null;
    }
  }

  Future<String?> captureFromUrl(Uri uri, String studentId) async {
    try {
      final promoterCode = uri.queryParameters['promo'];
      final shareSource = uri.queryParameters['source'] ?? 'direct_link';
      final itemType = uri.queryParameters['item_type'] ?? 'generic_landing';
      final itemId = uri.queryParameters['item_id'];
      final itemTitle = uri.queryParameters['item_title'];
      final utmSource = uri.queryParameters['utm_source'];
      final utmMedium = uri.queryParameters['utm_medium'];
      final utmCampaign = uri.queryParameters['utm_campaign'];
      // Visuel du créateur de contenu utilisé pour la pub (si présent dans le lien)
      final contentAssetId = uri.queryParameters['asset'];

      if (promoterCode != null && promoterCode.isNotEmpty) {
        final promoterId = await _getCommercialIdFromRefCode(promoterCode);
        if (promoterId != null) {
          return await registerShare(
            studentId: studentId,
            promoterCommercialId: promoterId,
            shareSource: shareSource,
            sharedItemType: itemType,
            sharedItemId: itemId,
            sharedItemTitle: itemTitle,
            utmSource: utmSource,
            utmMedium: utmMedium,
            utmCampaign: utmCampaign,
            contentAssetId: contentAssetId,
          );
        }
      }
      return null;
    } catch (e) {
      print('Error capturing from URL: $e');
      return null;
    }
  }

  Future<String?> _getCommercialIdFromRefCode(String refCode) async {
    try {
      final response = await _client
          .from('commercial_profiles')
          .select('user_id')
          .eq('ref_code', refCode)
          .eq('is_active', true)
          .maybeSingle();
      return response?['user_id'] as String?;
    } catch (e) {
      print('Error getting commercial ID from ref code: $e');
      return null;
    }
  }

  String generateShareUrl({
    required String baseUrl,
    required String refCode,
    required String shareSource,
    required String sharedItemType,
    String? sharedItemId,
    String? sharedItemTitle,
    String? utmCampaign,
  }) {
    // Source de vérité unique: le ref_link stocké en DB (commercial_profiles.ref_link).
    // On ne reconstruit plus d'URL en dur ici pour éviter toute divergence de domaine.
    final link = baseUrl.trim();
    if (link.isNotEmpty) return link;
    return 'https://academiea.com/ref/$refCode';
  }
}
