// Cloudflare Worker: R2 Image Upload Proxy for MoiMoi POS
// Deploy: npx wrangler deploy
// 
// wrangler.toml configuration required:
// name = "moimoi-r2-worker"
// main = "src/index.js"
// compatibility_date = "2024-01-01"
// 
// [[r2_buckets]]
// binding = "IMAGES_BUCKET"
// bucket_name = "moimoi-images"
//
// [vars]
// ALLOWED_ORIGINS = "http://localhost:3000,https://your-app.vercel.app"
// 
// Secret (set via: npx wrangler secret put UPLOAD_SECRET):
// UPLOAD_SECRET = "your-secret-key-here"

export default {
  async fetch(request, env, ctx) {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // POST /upload — Upload image to R2
      if (request.method === 'POST' && path === '/upload') {
        return await handleUpload(request, env, corsHeaders);
      }

      // GET /images/* — Serve image from R2
      if (request.method === 'GET' && path.startsWith('/images/')) {
        return await handleGet(path, env, corsHeaders);
      }

      // DELETE /images/* — Delete image from R2
      if (request.method === 'DELETE' && path.startsWith('/images/')) {
        return await handleDelete(request, path, env, corsHeaders);
      }

      return new Response(JSON.stringify({ error: 'Not Found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  },
};

async function handleUpload(request, env, corsHeaders) {
  // Verify auth
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || authHeader !== `Bearer ${env.UPLOAD_SECRET}`) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const contentType = request.headers.get('Content-Type') || '';

  let imageBytes;
  let ext = 'jpg';
  let folder = 'misc';

  if (contentType.includes('multipart/form-data')) {
    // Multipart upload
    const formData = await request.formData();
    const file = formData.get('file');
    folder = formData.get('folder') || 'misc';

    if (!file) {
      return new Response(JSON.stringify({ error: 'No file provided' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    imageBytes = await file.arrayBuffer();
    // Determine extension from file type
    const fileType = file.type || 'image/jpeg';
    ext = fileType.split('/').pop() || 'jpg';
    if (ext === 'jpeg') ext = 'jpg';
  } else if (contentType.includes('application/json')) {
    // JSON body with base64 data
    const body = await request.json();
    folder = body.folder || 'misc';

    if (!body.data) {
      return new Response(JSON.stringify({ error: 'No data provided' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Handle data URI: "data:image/webp;base64,..."
    let base64Data = body.data;
    if (base64Data.includes(',')) {
      const header = base64Data.split(',')[0];
      base64Data = base64Data.split(',')[1];
      // Extract extension from data URI
      const match = header.match(/image\/(\w+)/);
      if (match) ext = match[1] === 'jpeg' ? 'jpg' : match[1];
    }

    imageBytes = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0)).buffer;
  } else {
    return new Response(JSON.stringify({ error: 'Unsupported Content-Type' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Generate unique filename
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8);
  const key = `${folder}/${timestamp}_${random}.${ext}`;

  // Upload to R2
  await env.IMAGES_BUCKET.put(key, imageBytes, {
    httpMetadata: {
      contentType: `image/${ext === 'jpg' ? 'jpeg' : ext}`,
      cacheControl: 'public, max-age=31536000, immutable',
    },
  });

  // Build public URL
  // Option 1: Using worker URL itself
  const publicUrl = `${new URL(request.url).origin}/images/${key}`;

  return new Response(JSON.stringify({ 
    success: true, 
    url: publicUrl,
    key: key,
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function handleGet(path, env, corsHeaders) {
  // Remove /images/ prefix
  const key = path.replace('/images/', '');
  
  const object = await env.IMAGES_BUCKET.get(key);
  if (!object) {
    return new Response('Not Found', { status: 404, headers: corsHeaders });
  }

  const headers = new Headers(corsHeaders);
  headers.set('Content-Type', object.httpMetadata?.contentType || 'image/jpeg');
  headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  headers.set('ETag', object.httpEtag);

  return new Response(object.body, { headers });
}

async function handleDelete(request, path, env, corsHeaders) {
  // Verify auth
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || authHeader !== `Bearer ${env.UPLOAD_SECRET}`) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const key = path.replace('/images/', '');
  await env.IMAGES_BUCKET.delete(key);

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
