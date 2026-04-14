/// <reference lib="deno.ns" />
// Supabase Edge Function: payment-webhook
// Deploy: supabase functions deploy payment-webhook
// URL: https://<project-ref>.supabase.co/functions/v1/payment-webhook
//
// This function receives webhook data from SePay/Casso when a bank
// transaction is detected, matches it against pending upgrade requests,
// and auto-approves the premium subscription.
//
// SETUP:
// 1. Create this file at: supabase/functions/payment-webhook/index.ts
// 2. Set environment variable: SUPABASE_SERVICE_ROLE_KEY
// 3. Deploy: supabase functions deploy payment-webhook --no-verify-jwt
// 4. Add the function URL to SePay/Casso webhook settings

// deno-lint-ignore-file
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    
    // ── Parse webhook data ──
    // SePay format: { transferType, content, transferAmount, ... }
    // Casso format: { data: [{ description, amount, ... }] }
    
    let transferContent = ''
    let transferAmount = 0

    if (body.content) {
      // SePay format
      transferContent = body.content?.toUpperCase()?.trim() || ''
      transferAmount = Number(body.transferAmount) || 0
    } else if (body.data && Array.isArray(body.data)) {
      // Casso format
      const txn = body.data[0]
      transferContent = txn?.description?.toUpperCase()?.trim() || ''
      transferAmount = Math.abs(Number(txn?.amount)) || 0
    }

    console.log(`Webhook received: content="${transferContent}", amount=${transferAmount}`)

    if (!transferContent || transferAmount <= 0) {
      return new Response(
        JSON.stringify({ success: false, message: 'Invalid webhook data' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── Connect to Supabase ──
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, serviceRoleKey)

    // ── Find matching pending upgrade request ──
    // Transfer content format: "MOIMOI USERNAME PLANINDEX"
    const { data: requests, error: fetchErr } = await supabase
      .from('upgrade_requests')
      .select('*')
      .eq('status', 'pending')

    if (fetchErr || !requests?.length) {
      console.log('No pending requests found')
      return new Response(
        JSON.stringify({ success: false, message: 'No pending requests' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Match by transfer content (check if bank message contains our code)
    const matched = requests.find((r: any) => {
      const expected = (r.transfer_content || '').toUpperCase().trim()
      return transferContent.includes(expected) && transferAmount >= r.amount
    })

    if (!matched) {
      console.log('No matching request for content:', transferContent)
      return new Response(
        JSON.stringify({ success: false, message: 'No matching request' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Matched request: ${matched.id} for user ${matched.username}`)

    // ── Get user info to calculate new expiry ──
    const { data: user } = await supabase
      .from('users')
      .select('expires_at')
      .eq('username', matched.username)
      .single()

    let baseDate = new Date()
    if (user?.expires_at) {
      const existing = new Date(user.expires_at)
      if (existing > baseDate) baseDate = existing
    }
    baseDate.setDate(baseDate.getDate() + matched.months * 30)

    // ── Auto-approve: update user to premium ──
    await supabase.from('users').update({
      is_premium: true,
      expires_at: baseDate.toISOString(),
      show_vip_congrat: true,
    }).eq('username', matched.username)

    // Update store_infos
    await supabase.from('store_infos').update({
      is_premium: true,
    }).eq('store_id', matched.username)

    // Update request status to approved
    await supabase.from('upgrade_requests').update({
      status: 'approved',
    }).eq('id', matched.id)

    // Record premium payment history
    await supabase.from('premium_payments').insert({
      id: `pp_${Date.now()}`,
      username: matched.username,
      plan_name: matched.plan_name,
      months: matched.months,
      amount: matched.amount,
      paid_at: new Date().toISOString(),
    })

    // ── Send notification to sadmin(s) ──
    const { data: sadmins } = await supabase
      .from('users')
      .select('username')
      .eq('role', 'sadmin')

    if (sadmins?.length) {
      const notifications = sadmins.map((sa: any) => ({
        id: `noti_paid_${matched.id}_${sa.username}`,
        user_id: sa.username,
        title: 'Premium đã thanh toán ✅',
        message: `${matched.username} đã thanh toán gói ${matched.plan_name} (${transferAmount.toLocaleString('vi-VN')}đ). Đã tự động kích hoạt.`,
        type: 'upgrade_paid',
        time: new Date().toISOString(),
        read: false,
      }))
      await supabase.from('notifications').insert(notifications)
    }

    // ── Send notification to user ──
    await supabase.from('notifications').insert({
      id: `noti_approved_${matched.id}`,
      user_id: matched.username,
      title: 'Premium đã kích hoạt! 🎉',
      message: `Gói ${matched.plan_name} đã được kích hoạt thành công. Cảm ơn bạn!`,
      type: 'upgrade_approved',
      time: new Date().toISOString(),
      read: false,
    })

    console.log(`Auto-approved premium for ${matched.username}`)

    return new Response(
      JSON.stringify({ success: true, message: `Approved for ${matched.username}` }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err: any) {
    console.error('Webhook error:', err)
    return new Response(
      JSON.stringify({ success: false, error: err?.message ?? 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
