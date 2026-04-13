/**
 * Migration Script: Supabase base64 images → Cloudflare R2
 * 
 * Reads all base64 images from Supabase DB tables and uploads them
 * to Cloudflare R2 via the Worker proxy, then updates DB with new URLs.
 * 
 * Usage:
 *   cd cloudflare-worker
 *   npm install
 *   node migrate-images.js
 */

const SUPABASE_URL = 'https://xxspocdyxwoezelsngli.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4c3BvY2R5eHdvZXplbHNuZ2xpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxODI4MzEsImV4cCI6MjA4Nzc1ODgzMX0.4owe6Bj8lxgazmk2s4hLeVcN95-wMAuRdG6ymVb6rJk';
const WORKER_URL = 'https://moimoi-r2-worker.nma-store-data.workers.dev';
const UPLOAD_SECRET = 'Hihi123!';

// ── Helpers ─────────────────────────────────────────

async function supabaseGet(table, select = '*') {
  const url = `${SUPABASE_URL}/rest/v1/${table}?select=${encodeURIComponent(select)}`;
  const res = await fetch(url, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
    },
  });
  if (!res.ok) throw new Error(`GET ${table}: ${res.status} ${await res.text()}`);
  return res.json();
}

async function supabaseUpdate(table, matchColumn, matchValue, data) {
  const url = `${SUPABASE_URL}/rest/v1/${table}?${matchColumn}=eq.${encodeURIComponent(matchValue)}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal',
    },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`PATCH ${table}: ${res.status} ${await res.text()}`);
}

async function uploadToR2(base64Data, folder) {
  const res = await fetch(`${WORKER_URL}/upload`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${UPLOAD_SECRET}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ data: base64Data, folder }),
  });
  if (!res.ok) throw new Error(`Upload failed: ${res.status} ${await res.text()}`);
  const json = await res.json();
  return json.url;
}

function isBase64(value) {
  return value && typeof value === 'string' && value.startsWith('data:');
}

// ── Migration Tasks ─────────────────────────────────

async function migrateProducts() {
  console.log('\n📦 Migrating PRODUCTS...');
  const products = await supabaseGet('products', 'id,image');
  let migrated = 0, skipped = 0, failed = 0;

  for (const p of products) {
    if (!isBase64(p.image)) {
      skipped++;
      continue;
    }
    try {
      const url = await uploadToR2(p.image, 'products');
      await supabaseUpdate('products', 'id', p.id, { image: url });
      migrated++;
      console.log(`  ✅ Product ${p.id} → ${url.substring(0, 70)}...`);
    } catch (e) {
      failed++;
      console.error(`  ❌ Product ${p.id}: ${e.message}`);
    }
  }

  console.log(`  📊 Products: ${migrated} migrated, ${skipped} skipped, ${failed} failed`);
}

async function migrateUsers() {
  console.log('\n👤 Migrating USERS (avatars)...');
  const users = await supabaseGet('users', 'username,avatar');
  let migrated = 0, skipped = 0, failed = 0;

  for (const u of users) {
    if (!isBase64(u.avatar)) {
      skipped++;
      continue;
    }
    try {
      const url = await uploadToR2(u.avatar, 'avatars');
      await supabaseUpdate('users', 'username', u.username, { avatar: url });
      migrated++;
      console.log(`  ✅ User ${u.username} → ${url.substring(0, 70)}...`);
    } catch (e) {
      failed++;
      console.error(`  ❌ User ${u.username}: ${e.message}`);
    }
  }

  console.log(`  📊 Users: ${migrated} migrated, ${skipped} skipped, ${failed} failed`);
}

async function migrateStoreInfo() {
  console.log('\n🏪 Migrating STORE_INFO (logos + QR)...');
  const stores = await supabaseGet('store_infos', 'store_id,logo_url,qr_image_url');
  let migrated = 0, skipped = 0, failed = 0;

  for (const s of stores) {
    const updates = {};

    // Logo
    if (isBase64(s.logo_url)) {
      try {
        const url = await uploadToR2(s.logo_url, 'logos');
        updates.logo_url = url;
        console.log(`  ✅ Store ${s.store_id} logo → ${url.substring(0, 70)}...`);
      } catch (e) {
        failed++;
        console.error(`  ❌ Store ${s.store_id} logo: ${e.message}`);
      }
    } else {
      skipped++;
    }

    // QR image
    if (isBase64(s.qr_image_url)) {
      try {
        const url = await uploadToR2(s.qr_image_url, 'qr');
        updates.qr_image_url = url;
        console.log(`  ✅ Store ${s.store_id} QR → ${url.substring(0, 70)}...`);
      } catch (e) {
        failed++;
        console.error(`  ❌ Store ${s.store_id} QR: ${e.message}`);
      }
    } else {
      skipped++;
    }

    if (Object.keys(updates).length > 0) {
      await supabaseUpdate('store_infos', 'store_id', s.store_id, updates);
      migrated++;
    }
  }

  console.log(`  📊 StoreInfo: ${migrated} migrated, ${skipped} skipped, ${failed} failed`);
}

// ── Main ────────────────────────────────────────────

async function main() {
  console.log('🚀 Starting migration: Supabase base64 → Cloudflare R2');
  console.log(`   Worker: ${WORKER_URL}`);
  console.log(`   Supabase: ${SUPABASE_URL}`);

  // Test Worker connectivity
  try {
    const test = await fetch(`${WORKER_URL}/upload`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${UPLOAD_SECRET}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        data: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        folder: 'test',
      }),
    });
    if (!test.ok) throw new Error(`${test.status}`);
    console.log('   ✅ Worker connection OK\n');
  } catch (e) {
    console.error(`   ❌ Worker connection FAILED: ${e.message}`);
    console.error('   Aborting migration.');
    process.exit(1);
  }

  const skipProducts = process.argv.includes('--skip-products');

  if (!skipProducts) {
    await migrateProducts();
  } else {
    console.log('\n📦 Skipping products (already migrated)');
  }
  await migrateUsers();
  await migrateStoreInfo();

  console.log('\n🎉 Migration complete!');
}

main().catch(e => {
  console.error('💥 Fatal error:', e);
  process.exit(1);
});
