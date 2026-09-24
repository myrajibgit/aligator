#!/usr/bin/env node
/**
 * upload_syllabi.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Admin helper script to upload textbook / syllabus PDFs to Firebase Storage
 * at the path: syllabi/{subjectId}/textbook.pdf
 *
 * USAGE:
 *   node seed_data/upload_syllabi.js
 *
 * PREREQUISITES:
 *   1. A Firebase service account key (JSON) saved locally.
 *   2. Set GOOGLE_APPLICATION_CREDENTIALS env var, OR put path in serviceAccountPath below.
 *   3. Update the SUBJECTS array below to match your real subject IDs and PDF paths.
 *
 * This script uses the Firebase Admin SDK, which bypasses Storage Rules —
 * so it can run from any machine with admin credentials.
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// ── Configuration ─────────────────────────────────────────────────────────────

// Option A: Set GOOGLE_APPLICATION_CREDENTIALS env var before running
// Option B: Uncomment and set the path below
// const serviceAccountPath = './serviceAccountKey.json';

const FIREBASE_STORAGE_BUCKET = 'YOUR_PROJECT_ID.appspot.com'; // ← Change this

/**
 * Map of subjectId → local PDF file path.
 * The subjectId must match what you use in Firestore (e.g. "mathematics", "physics").
 * 
 * Example:
 *   mathematics → textbooks/math_grade10.pdf
 *   physics     → textbooks/physics_grade10.pdf
 */
const SYLLABI = [
  // Class 10 specific IDs (matches default seed data)
  { subjectId: 'maths_10',     localPath: './textbooks/mathematics.pdf' },
  { subjectId: 'physics_10',   localPath: './textbooks/physics.pdf' },
  { subjectId: 'chemistry_10', localPath: './textbooks/chemistry.pdf' },
  { subjectId: 'biology_10',   localPath: './textbooks/biology.pdf' },
  { subjectId: 'english_10',   localPath: './textbooks/english.pdf' },
  // Generic IDs
  { subjectId: 'mathematics',  localPath: './textbooks/mathematics.pdf' },
  { subjectId: 'physics',      localPath: './textbooks/physics.pdf' },
  { subjectId: 'chemistry',    localPath: './textbooks/chemistry.pdf' },
  { subjectId: 'biology',      localPath: './textbooks/biology.pdf' },
  { subjectId: 'english',      localPath: './textbooks/english.pdf' },
  { subjectId: 'history',      localPath: './textbooks/history.pdf' },
  { subjectId: 'geography',    localPath: './textbooks/geography.pdf' },
  { subjectId: 'computer',     localPath: './textbooks/computer_science.pdf' },
];

// ── Init Firebase Admin ────────────────────────────────────────────────────────

function initFirebase() {
  if (admin.apps.length) return;

  const options = { storageBucket: FIREBASE_STORAGE_BUCKET };

  // Use service account key if GOOGLE_APPLICATION_CREDENTIALS is not set
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({ ...options, credential: admin.credential.applicationDefault() });
  } else if (typeof serviceAccountPath !== 'undefined') {
    const sa = require(path.resolve(serviceAccountPath));
    admin.initializeApp({ ...options, credential: admin.credential.cert(sa) });
  } else {
    console.error(
      '❌  No credentials found.\n' +
      '   Set GOOGLE_APPLICATION_CREDENTIALS env var, or set serviceAccountPath in the script.'
    );
    process.exit(1);
  }
}

// ── Upload function ────────────────────────────────────────────────────────────

async function uploadSyllabus({ subjectId, localPath }) {
  const bucket = admin.storage().bucket();
  const destPath = `syllabi/${subjectId}/textbook.pdf`;

  const absoluteLocal = path.resolve(localPath);

  if (!fs.existsSync(absoluteLocal)) {
    console.warn(`⚠️  Skipping ${subjectId}: file not found at ${absoluteLocal}`);
    return;
  }

  const fileSizeBytes = fs.statSync(absoluteLocal).size;
  const fileSizeMB = (fileSizeBytes / (1024 * 1024)).toFixed(1);
  console.log(`📄 Uploading ${subjectId} (${fileSizeMB} MB) → ${destPath}`);

  try {
    await bucket.upload(absoluteLocal, {
      destination: destPath,
      metadata: {
        contentType: 'application/pdf',
        metadata: {
          uploadedAt: new Date().toISOString(),
          subjectId,
          uploadedBy: 'admin-script',
        },
      },
    });

    // Also write a metadata doc to Firestore for easy querying
    await admin.firestore().collection('syllabi').doc(subjectId).set({
      subjectId,
      storagePath: destPath,
      uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
      fileSizeBytes,
    }, { merge: true });

    console.log(`   ✅ Done: gs://${FIREBASE_STORAGE_BUCKET}/${destPath}`);
  } catch (err) {
    console.error(`   ❌ Failed to upload ${subjectId}:`, err.message);
  }
}

// ── Main ───────────────────────────────────────────────────────────────────────

async function main() {
  console.log('\n🚀 StudyCompete — Admin Syllabus Uploader\n');
  initFirebase();

  let uploaded = 0;
  let skipped = 0;

  for (const syllabus of SYLLABI) {
    const exists = fs.existsSync(path.resolve(syllabus.localPath));
    if (exists) {
      await uploadSyllabus(syllabus);
      uploaded++;
    } else {
      console.log(`⏭️  Skipping ${syllabus.subjectId} (PDF not found)`);
      skipped++;
    }
  }

  console.log(`\n✨ Upload complete: ${uploaded} uploaded, ${skipped} skipped.`);
  console.log(`\nStudents can now verify their notes for: `);
  console.log(SYLLABI.filter((s) => fs.existsSync(path.resolve(s.localPath)))
    .map((s) => `  • ${s.subjectId}`)
    .join('\n'));
  console.log('');

  process.exit(0);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
