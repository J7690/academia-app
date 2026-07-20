// ========================================
// ACADEMIA - EDGE FUNCTION
// SEND-RECEIPT-EMAIL : Envoyer le reçu PDF par email à l'étudiant
// ========================================
// Auth: service_role (trigger only)
// Uses Resend API for email delivery

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const RESEND_FROM_EMAIL = Deno.env.get('RESEND_FROM_EMAIL') ?? 'noreply@academia.bj';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    // Auth: service role only (for trigger)
    const authHeader = req.headers.get('Authorization') ?? '';
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    
    const isServiceRole = authHeader.includes(SUPABASE_SERVICE_ROLE_KEY);
    if (!isServiceRole) {
      return new Response(
        JSON.stringify({ success: false, error: 'not_authorized' }),
        { status: 403, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const body = await req.json();
    const { receipt_id } = body;

    if (!receipt_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'missing_receipt_id' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // Load receipt with payment and student info
    const { data: receipt, error: receiptError } = await supabase
      .schema('app')
      .from('payment_receipts')
      .select(`
        *,
        payment:application_payments(
          id,
          amount_due,
          amount_paid,
          currency,
          channel,
          reference_code,
          external_reference,
          payment_reason,
          student_id,
          student:auth.users(email, user_metadata)
        )
      `)
      .eq('id', receipt_id)
      .single();

    if (receiptError || !receipt) {
      console.error('[send-receipt-email] Receipt not found:', receiptError);
      return new Response(
        JSON.stringify({ success: false, error: 'receipt_not_found' }),
        { status: 404, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const payment = receipt.payment;
    if (!payment) {
      console.error('[send-receipt-email] Payment not found for receipt');
      return new Response(
        JSON.stringify({ success: false, error: 'payment_not_found' }),
        { status: 404, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const student = payment.student;
    if (!student || !student.email) {
      console.error('[send-receipt-email] Student email not found');
      return new Response(
        JSON.stringify({ success: false, error: 'student_email_not_found' }),
        { status: 404, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const studentEmail = student.email;
    const studentName = student.user_metadata?.full_name || student.user_metadata?.first_name || 'Étudiant';

    // Generate email content
    const emailSubject = `Reçu de paiement Academia - ${receipt.receipt_number}`;
    const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #2E7D32; color: white; padding: 20px; text-align: center; }
    .content { background: #f5f5f5; padding: 20px; margin: 20px 0; }
    .receipt-number { font-size: 18px; font-weight: bold; color: #2E7D32; }
    .amount { font-size: 24px; font-weight: bold; color: #333; }
    .footer { text-align: center; font-size: 12px; color: #666; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Academia</h1>
      <p>Reçu de paiement</p>
    </div>
    <div class="content">
      <p>Bonjour ${studentName},</p>
      <p>Votre paiement a été confirmé avec succès.</p>
      <p><strong>Numéro de reçu:</strong> <span class="receipt-number">${receipt.receipt_number}</span></p>
      <p><strong>Montant payé:</strong> <span class="amount">${payment.amount_paid} ${payment.currency}</span></p>
      <p><strong>Date:</strong> ${new Date(receipt.issued_at).toLocaleString('fr-FR')}</p>
      <p><strong>Motif:</strong> ${payment.payment_reason}</p>
      <p><strong>Référence:</strong> ${payment.reference_code || 'N/A'}</p>
      <p>Vous pouvez consulter le détail de votre reçu dans votre espace étudiant.</p>
    </div>
    <div class="footer">
      <p>Ce reçu a été généré automatiquement par la plateforme Academia.</p>
      <p>Pour toute question, contactez notre support.</p>
    </div>
  </div>
</body>
</html>
    `;

    // Send email via Resend
    if (!RESEND_API_KEY) {
      console.error('[send-receipt-email] RESEND_API_KEY not configured');
      return new Response(
        JSON.stringify({ success: false, error: 'email_not_configured' }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: RESEND_FROM_EMAIL,
        to: studentEmail,
        subject: emailSubject,
        html: emailHtml,
      }),
    });

    const emailData = await emailResponse.json();
    console.log('[send-receipt-email] Email response:', JSON.stringify(emailData));

    if (!emailResponse.ok) {
      console.error('[send-receipt-email] Email send failed:', emailData);
      return new Response(
        JSON.stringify({ success: false, error: 'email_send_failed', details: emailData }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[send-receipt-email] Receipt ${receipt_id} sent to ${studentEmail}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Email sent successfully',
        email_id: emailData.id,
      }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    console.error('[send-receipt-email] Error:', err);
    return new Response(
      JSON.stringify({ success: false, error: 'internal_error', details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }
});
