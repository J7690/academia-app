-- ============================================================================
-- Script de suppression de toutes les vidéos de challenges
-- Date: 16 Juin 2026
-- Objectif: Nettoyage complet des buckets challenge-media et video-assets
-- ============================================================================

-- ATTENTION: Ce script va supprimer TOUTES les vidéos des buckets suivants:
-- 1. challenge-media (vidéos challenges, thumbnails, free videos)
-- 2. video-assets (pipeline vidéo unifié, renditions)
--
-- Exécutez ce script dans le Supabase SQL Editor avec le rôle postgres (owner)

-- ============================================================================
-- ÉTAPE 1: Suppression des fichiers du bucket challenge-media
-- ============================================================================

-- Supprimer tous les objets du bucket challenge-media
DELETE FROM storage.objects
WHERE bucket_id = 'challenge-media';

-- ============================================================================
-- ÉTAPE 2: Suppression des fichiers du bucket video-assets
-- ============================================================================

-- Supprimer tous les objets du bucket video-assets
DELETE FROM storage.objects
WHERE bucket_id = 'video-assets';

-- ============================================================================
-- ÉTAPE 3: Nettoyage optionnel des tables liées (décommenter si nécessaire)
-- ============================================================================

-- Supprimer les participations challenges (si vous voulez aussi nettoyer la DB)
-- DELETE FROM app.challenge_participations;

-- Supprimer les challenges (si vous voulez aussi nettoyer la DB)
-- DELETE FROM app.challenges;

-- Supprimer les video_assets (si vous voulez aussi nettoyer la DB)
-- DELETE FROM app.video_assets;

-- Supprimer les video_renditions (si vous voulez aussi nettoyer la DB)
-- DELETE FROM app.video_renditions;

-- ============================================================================
-- ÉTAPE 4: Vérification
-- ============================================================================

-- Vérifier que les buckets sont vides
SELECT 
    bucket_id,
    COUNT(*) as file_count
FROM storage.objects
WHERE bucket_id IN ('challenge-media', 'video-assets')
GROUP BY bucket_id;

-- Résultat attendu: 0 rows (buckets vides)
