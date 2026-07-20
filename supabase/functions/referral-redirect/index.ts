import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/')
    
    // Expected format: /functions/v1/referral-redirect/ref/REF_CODE
    // Find the 'ref' segment in the path
    const refIndex = pathParts.findIndex(part => part === 'ref')
    
    if (refIndex === -1 || refIndex + 1 >= pathParts.length) {
      return new Response('Invalid URL format - missing /ref/ segment', { status: 400, headers: corsHeaders })
    }

    const refCode = pathParts[refIndex + 1]
    
    if (!refCode || refCode.length === 0) {
      return new Response('Missing referral code', { status: 400, headers: corsHeaders })
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    // commercial_profiles / referral_tokens vivent dans le schéma "app", pas "public".
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      db: { schema: 'app' },
    })

    // Get commercial_id from ref_code
    const { data: commercialProfile, error: profileError } = await supabase
      .from('commercial_profiles')
      .select('user_id')
      .eq('ref_code', refCode)
      .eq('is_active', true)
      .single()

    if (profileError || !commercialProfile) {
      return new Response('Commercial not found', { status: 404, headers: corsHeaders })
    }

    const commercialId = commercialProfile.user_id

    // Détecte la plateforme du visiteur pour router correctement
    const userAgent = req.headers.get('user-agent') || ''
    const isAndroid = /Android/i.test(userAgent)
    const isIOS = /iPhone|iPad|iPod/i.test(userAgent)
    const isMobile = isAndroid || isIOS

    // Desktop/web : pas d'app à installer, on renvoie vers la landing web
    // qui sait déjà capter ?ref= (auth_landing_screen.dart -> SharedPreferences).
    if (!isMobile) {
      const frontUrl = Deno.env.get('FRONT_URL') || 'https://app.academiea.com'
      return Response.redirect(`${frontUrl}/?ref=${refCode}`, 302)
    }

    // Generate unique token
    const token = Array.from(crypto.getRandomValues(new Uint8Array(16)))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('')
      .toUpperCase()

    // Store token in referral_tokens table
    const { error: insertError } = await supabase
      .from('referral_tokens')
      .insert({
        token,
        commercial_id: commercialId,
        expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(), // 30 days
      })

    if (insertError) {
      console.error('Error inserting referral token:', insertError)
      return new Response('Error creating referral token', { status: 500, headers: corsHeaders })
    }

    if (isIOS) {
      // Pas d'app iOS pour le moment : on renvoie vers la landing web en attendant.
      const frontUrl = Deno.env.get('FRONT_URL') || 'https://app.academiea.com'
      return Response.redirect(`${frontUrl}/?ref=${refCode}`, 302)
    }

    // Android : redirect vers Play Store avec le referrer (lu par InstallReferrerService)
    const playStoreUrl = `https://play.google.com/store/apps/details?id=com.academia.nexiomgroup.app&referrer=${token}`

    return Response.redirect(playStoreUrl, 302)

  } catch (error) {
    console.error('Error in referral-redirect:', error)
    return new Response('Internal server error', { status: 500, headers: corsHeaders })
  }
})
