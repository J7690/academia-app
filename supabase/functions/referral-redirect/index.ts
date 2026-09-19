import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/')

    const refIndex = pathParts.findIndex(part => part === 'ref')

    if (refIndex === -1 || refIndex + 1 >= pathParts.length) {
      return new Response('Invalid URL format - missing /ref/ segment', { status: 400, headers: corsHeaders })
    }

    const refCode = pathParts[refIndex + 1]

    if (!refCode || refCode.length === 0) {
      return new Response('Missing referral code', { status: 400, headers: corsHeaders })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      db: { schema: 'app' },
    })

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

    // Generer un jeton unique pour TOUTES les plateformes
    const token = Array.from(crypto.getRandomValues(new Uint8Array(16)))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('')
      .toUpperCase()

    const { error: insertError } = await supabase
      .from('referral_tokens')
      .insert({
        token,
        commercial_id: commercialId,
        expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      })

    if (insertError) {
      console.error('Error inserting referral token:', insertError)
      return new Response('Error creating referral token', { status: 500, headers: corsHeaders })
    }

    // Si le client demande du JSON (deep link handler dans l'app),
    // renvoyer le jeton sans rediriger.
    const acceptHeader = req.headers.get('accept') || ''
    if (acceptHeader.includes('application/json')) {
      return new Response(JSON.stringify({ token }), {
        headers: { ...corsHeaders, 'content-type': 'application/json' },
      })
    }

    const userAgent = req.headers.get('user-agent') || ''
    const isAndroid = /Android/i.test(userAgent)

    if (isAndroid) {
      const playStoreUrl = `https://play.google.com/store/apps/details?id=com.academia.nexiomgroup.app&referrer=${token}`
      return Response.redirect(playStoreUrl, 302)
    }

    // Web et iOS : rediriger vers la landing avec le jeton (pas le code)
    const frontUrl = Deno.env.get('FRONT_URL') || 'https://app.academiea.com'
    return Response.redirect(`${frontUrl}/?rt=${token}`, 302)

  } catch (error) {
    console.error('Error in referral-redirect:', error)
    return new Response('Internal server error', { status: 500, headers: corsHeaders })
  }
})
