const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const schools = require('./schools.json');
const classes = require('./classes.json');
const subjects = require('./subjects.json');
const questions = require('./questions.json');

// Initialize for emulator if FIRESTORE_EMULATOR_HOST is set
if (process.env.FIRESTORE_EMULATOR_HOST) {
  console.log(`Connecting to emulator at ${process.env.FIRESTORE_EMULATOR_HOST}`);
  admin.initializeApp({ projectId: 'studycompete' });
} else {
  console.log('Connecting to production Firestore');
  admin.initializeApp(); // uses GOOGLE_APPLICATION_CREDENTIALS
}

const db = admin.firestore();

async function seedCollection(collectionName, data, idField = 'id') {
  console.log(`Seeding ${collectionName}...`);
  const batch = db.batch();
  let count = 0;

  for (const item of data) {
    const docRef = db.collection(collectionName).doc(item[idField]);
    batch.set(docRef, item);
    count++;
  }

  await batch.commit();
  console.log(`Seeded ${count} documents into ${collectionName}`);
}

async function seedQuestions() {
  console.log(`Seeding questionBank...`);
  const batch = db.batch();
  let count = 0;

  for (const item of questions) {
    // The path is /questionBank/{subjectId}/questions/{questionId} according to typical pattern
    // or just /questionBank/{questionId} based on the rules structure which matches /questionBank/{subjectId}/{document=**}
    const docRef = db.collection('questionBank').doc(item.subjectId).collection('questions').doc(item.id);
    batch.set(docRef, item);
    count++;
  }

  await batch.commit();
  console.log(`Seeded ${count} documents into questionBank`);
}

const chapters = require('./chapters.json');

async function seedChapters() {
  console.log(`Seeding chapters into questionBank...`);
  const batch = db.batch();
  let count = 0;

  for (const item of chapters) {
    const docRef = db.collection('questionBank').doc(item.subjectId).collection('chapters').doc(item.id);
    batch.set(docRef, item);
    count++;
  }

  await batch.commit();
  console.log(`Seeded ${count} chapter keyword documents into questionBank`);
}

async function seedSyllabi() {
  console.log(`Seeding syllabi metadata...`);
  const batch = db.batch();
  let count = 0;

  for (const item of subjects) {
    const docRef = db.collection('syllabi').doc(item.id);
    batch.set(docRef, {
      subjectId: item.id,
      subjectName: item.name,
      storagePath: `syllabi/${item.id}/textbook.pdf`,
      chapters: item.chapters || [],
      uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    count++;
  }

  await batch.commit();
  console.log(`Seeded ${count} syllabus metadata documents into syllabi`);
}

async function seed() {
  try {
    await seedCollection('schools', schools);
    await seedCollection('classes', classes);
    await seedCollection('subjects', subjects);
    await seedChapters();
    await seedQuestions();
    await seedSyllabi();
    
    console.log('All seed data inserted successfully.');
  } catch (error) {
    console.error('Error seeding data:', error);
  }
}

seed().catch(console.error);

