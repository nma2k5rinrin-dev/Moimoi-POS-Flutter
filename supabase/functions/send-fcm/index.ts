import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { JWT } from "npm:google-auth-library@9"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const payload = await req.json()
        const order = payload.record // Triggered from database insert webhook
        if (!order) {
            throw new Error("Missing order record")
        }

        // Khởi tạo Supabase client bằng quyền Admin (Service Role)
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Lấy user_id của nhân viên/quản lý thuộc cửa hàng này
        const { data: users, error: userError } = await supabaseClient
            .from('users')
            .select('id')
            .eq('store_id', order.store_id)

        if (userError || !users?.length) {
            return new Response(JSON.stringify({ message: "No users found for this store" }), { headers: corsHeaders })
        }

        const userIds = users.map(u => u.id)

        // Lấy các mã FCM Tokens của những user đó
        const { data: tokensData, error: tokenError } = await supabaseClient
            .from('fcm_tokens')
            .select('token')
            .in('user_id', userIds)

        if (tokenError || !tokensData?.length) {
            return new Response(JSON.stringify({ message: "No fcm devices registered" }), { headers: corsHeaders })
        }

        const tokens = tokensData.map(t => t.token)

        // Lấy thông tin tài khoản Service Account của bên Firebase (cấu hình trong Supabase Secrets)
        const serviceAccountJsonStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")
        if (!serviceAccountJsonStr) {
            throw new Error("Missing FIREBASE_SERVICE_ACCOUNT secret. Please set it in Supabase Secrets.")
        }

        const serviceAccount = JSON.parse(serviceAccountJsonStr)
        const projectId = serviceAccount.project_id

        // Lấy OAuth2 Token (Mới nhất theo chuẩn HTTP v1 của Google)
        const jwtClient = new JWT({
            email: serviceAccount.client_email,
            key: serviceAccount.private_key,
            scopes: ['https://www.googleapis.com/auth/firebase.messaging']
        });
        const accessTokenObj = await jwtClient.getAccessToken();
        const accessToken = accessTokenObj.token;

        // Format tin nhắn gửi
        const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
        let successCount = 0;

        // Firebase HTTP v1 chỉ cho phép gửi từng thiết bị, ta dùng vòng lặp push
        for (const token of tokens) {
            const fcmPayload = {
                message: {
                    token: token,
                    notification: {
                        title: "Đơn hàng mới!",
                        body: `Có đơn hàng trị giá ${order.total_amount_after_discount}đ vừa được tạo.`
                    },
                    android: {
                        priority: "high", // Quan trọng nhất để đánh thức màn hình (Doze mode)
                        notification: {
                            sound: "default",
                            channel_id: "high_importance_channel"
                        }
                    },
                    data: {
                        order_id: order.id,
                        action: 'new_order'
                    }
                }
            }

            const res = await fetch(fcmUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${accessToken}`
                },
                body: JSON.stringify(fcmPayload)
            })

            if (res.ok) successCount++;
        }

        return new Response(
            JSON.stringify({ message: `Successfully sent ${successCount}/${tokens.length} notifications` }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
