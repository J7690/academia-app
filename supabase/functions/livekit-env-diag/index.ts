// Recette LiveKit Cloud validee le 26 juillet 2026 : creation de salle,
// signalisation WebSocket acceptee par le SFU, listage et suppression.
// Fonction neutralisee ensuite — elle ne lit plus aucun secret et ne mint
// plus aucun token. Supprimable par : supabase functions delete livekit-env-diag

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

serve(() =>
  new Response(
    JSON.stringify({ status: 'retiree', recette_validee: '2026-07-26' }),
    { status: 410, headers: { 'Content-Type': 'application/json' } },
  )
);
