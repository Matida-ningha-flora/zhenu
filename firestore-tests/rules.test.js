// Tests des règles Firestore (émulateur local, aucun accès au vrai projet).
// Lancement : cd firestore-tests && npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayUnion,
  doc,
  getDoc,
  getDocs,
  collection,
  query,
  where,
  serverTimestamp,
  setDoc,
  updateDoc,
  increment,
} from 'firebase/firestore';

let env;

const awa = () => env.authenticatedContext('awa', { email: 'awa@test.com' }).firestore();
const paul = () => env.authenticatedContext('paul', { email: 'paul@test.com' }).firestore();
const eve = () => env.authenticatedContext('eve', { email: 'eve@test.com' }).firestore();
const admin = () => env.authenticatedContext('admin', { email: 'admin@test.com' }).firestore();
const guest = () => env.unauthenticatedContext().firestore();

async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-neurosigne',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed('users/admin', { name: 'Admin', role: 'admin', email: 'admin@test.com' });
  await seed('users/awa', { name: 'Awa', role: 'user', email: 'awa@test.com' });
  await seed('users/paul', { name: 'Paul', role: 'user', email: 'paul@test.com' });
  await seed('users/eve', { name: 'Eve', role: 'user', email: 'eve@test.com' });
});

describe('comptes', () => {
  test('inscription possible en « user », jamais en « admin »', async () => {
    const db = env.authenticatedContext('new', { email: 'new@test.com' }).firestore();
    await assertFails(setDoc(doc(db, 'users/new'), { name: 'N', role: 'admin', suspended: false }));
    await assertSucceeds(setDoc(doc(db, 'users/new'), { name: 'N', role: 'user', suspended: false }));
  });

  test('un utilisateur ne change pas son rôle ni sa suspension', async () => {
    await assertFails(updateDoc(doc(awa(), 'users/awa'), { role: 'admin' }));
    await assertFails(updateDoc(doc(awa(), 'users/awa'), { suspended: false }));
    await assertSucceeds(updateDoc(doc(awa(), 'users/awa'), { name: 'Awa N.' }));
  });

  test('seul l’admin lit les autres comptes et modifie les rôles', async () => {
    await assertFails(getDoc(doc(awa(), 'users/paul')));
    await assertSucceeds(getDoc(doc(admin(), 'users/paul')));
    await assertSucceeds(updateDoc(doc(admin(), 'users/paul'), { role: 'admin' }));
  });

  test('un visiteur non connecté ne lit rien', async () => {
    await assertFails(getDoc(doc(guest(), 'users/awa')));
    await assertFails(getDoc(doc(guest(), 'config/app')));
  });
});

describe('contenus administrés', () => {
  test('annonces et réglages : lecture pour tous, écriture admin', async () => {
    await assertFails(setDoc(doc(awa(), 'announcements/a1'), { message: 'x' }));
    await assertSucceeds(setDoc(doc(admin(), 'announcements/a1'), { message: 'x' }));
    await assertSucceeds(getDoc(doc(awa(), 'announcements/a1')));
    await assertFails(setDoc(doc(awa(), 'config/app'), { settings: {} }));
  });

  test('propositions de signes : en attente uniquement, validées par l’admin', async () => {
    const pending = { authorId: 'awa', status: 'En attente', word: 'MOTO', description: 'Guidon' };
    await assertFails(setDoc(doc(awa(), 'signProposals/p0'), { ...pending, status: 'Validé' }));
    await assertFails(setDoc(doc(awa(), 'signProposals/p0'), { ...pending, authorId: 'paul' }));
    await assertSucceeds(setDoc(doc(awa(), 'signProposals/p1'), pending));
    await assertFails(getDoc(doc(paul(), 'signProposals/p1')));
    await assertSucceeds(getDoc(doc(awa(), 'signProposals/p1')));
    await assertFails(updateDoc(doc(awa(), 'signProposals/p1'), { status: 'Validé' }));
    await assertSucceeds(updateDoc(doc(admin(), 'signProposals/p1'), { status: 'Validé' }));
    await assertFails(setDoc(doc(awa(), 'signs/s1'), { word: 'MOTO' }));
    await assertSucceeds(setDoc(doc(admin(), 'signs/s1'), { word: 'MOTO' }));
  });

  test('sans modération, un utilisateur publie directement', async () => {
    await seed('config/app', { settings: { communityModerationRequired: false } });
    await assertSucceeds(setDoc(doc(awa(), 'signs/s2'), { word: 'TAXI' }));
  });

  test('statistiques : incrément par tous, lecture admin', async () => {
    await assertSucceeds(setDoc(doc(awa(), 'stats/global'),
      { translations: increment(1), searchedTerms: { MERCI: increment(1) } }, { merge: true }));
    await assertFails(setDoc(doc(awa(), 'stats/global'), { hacked: true }, { merge: true }));
    await assertFails(getDoc(doc(awa(), 'stats/global')));
    await assertSucceeds(getDoc(doc(admin(), 'stats/global')));
  });
});

describe('conversations à distance', () => {
  const room = {
    title: 'Famille',
    code: 'ABC234',
    createdBy: 'awa',
    participants: ['awa'],
    participantNames: { awa: 'Awa' },
    invitedEmails: ['eve@test.com'],
    active: true,
    lastMessage: '',
    lastSenderName: '',
  };

  test('création : uniquement en tant qu’organisateur seul', async () => {
    await assertFails(setDoc(doc(awa(), 'conversations/r0'), { ...room, participants: ['awa', 'paul'] }));
    await assertFails(setDoc(doc(awa(), 'conversations/r0'), { ...room, createdBy: 'paul' }));
    await assertSucceeds(setDoc(doc(awa(), 'conversations/r1'), room));
    await assertSucceeds(setDoc(doc(awa(), 'roomCodes/ABC234'), { roomId: 'r1', createdBy: 'awa' }));
    await assertSucceeds(getDoc(doc(paul(), 'roomCodes/ABC234')));
  });

  test('rejoindre : on s’ajoute soi-même, jamais quelqu’un d’autre', async () => {
    await seed('conversations/r1', room);
    await assertFails(updateDoc(doc(paul(), 'conversations/r1'), {
      participants: ['awa', 'eve'], participantNames: { awa: 'Awa', eve: 'Eve' },
    }));
    await assertSucceeds(updateDoc(doc(paul(), 'conversations/r1'), {
      participants: ['awa', 'paul'], participantNames: { awa: 'Awa', paul: 'Paul' },
    }));
  });

  test('messages : réservés aux participants, sans usurpation', async () => {
    await seed('conversations/r1', room);
    const msg = (sender, text = 'Bonjour') => ({
      senderId: sender, senderName: sender, text, signed: false, createdAt: serverTimestamp(),
    });
    await assertSucceeds(setDoc(doc(awa(), 'conversations/r1/messages/m1'), msg('awa')));
    await assertFails(setDoc(doc(awa(), 'conversations/r1/messages/m2'), msg('paul')));
    await assertFails(setDoc(doc(awa(), 'conversations/r1/messages/m3'), msg('awa', 'x'.repeat(1001))));
    await assertFails(setDoc(doc(paul(), 'conversations/r1/messages/m4'), msg('paul')));
    await assertFails(getDoc(doc(paul(), 'conversations/r1/messages/m1')));
    await assertSucceeds(getDoc(doc(awa(), 'conversations/r1/messages/m1')));
    await assertFails(updateDoc(doc(awa(), 'conversations/r1/messages/m1'), { text: 'modifié' }));
  });

  test('lecture et présence : chacun ne modifie que sa propre entrée', async () => {
    await seed('conversations/r1', { ...room, participants: ['awa', 'paul'], lastRead: {} });
    await assertSucceeds(updateDoc(doc(paul(), 'conversations/r1'), { 'lastRead.paul': serverTimestamp() }));
    await assertFails(updateDoc(doc(paul(), 'conversations/r1'), { 'lastRead.awa': serverTimestamp() }));
    await assertFails(updateDoc(doc(paul(), 'conversations/r1'), { title: 'Piraté' }));
  });

  test('profil (sourd, entendant) : chacun indique seulement le sien', async () => {
    await seed('conversations/r1', { ...room, participants: ['awa', 'paul'] });
    await assertSucceeds(updateDoc(doc(paul(), 'conversations/r1'), { 'participantProfiles.paul': 'deaf' }));
    await assertFails(updateDoc(doc(paul(), 'conversations/r1'), { 'participantProfiles.awa': 'hearing' }));
    await assertFails(updateDoc(doc(paul(), 'conversations/r1'), { 'participantProfiles.paul': 'pirate' }));
    await assertFails(updateDoc(doc(eve(), 'conversations/r1'), { 'participantProfiles.eve': 'deaf' }));
  });

  test('listes : participants et invités seulement', async () => {
    await seed('conversations/r1', room);
    const q = (db, field, value) => getDocs(query(collection(db, 'conversations'), where(field, 'array-contains', value)));
    await assertSucceeds(q(awa(), 'participants', 'awa'));
    await assertSucceeds(q(eve(), 'invitedEmails', 'eve@test.com'));
    await assertFails(q(paul(), 'invitedEmails', 'eve@test.com'));
  });

  test('invitation refusée, départ et clôture', async () => {
    await seed('conversations/r1', { ...room, participants: ['awa', 'paul'] });
    await assertSucceeds(updateDoc(doc(eve(), 'conversations/r1'), { invitedEmails: [] }));
    await assertFails(updateDoc(doc(paul(), 'conversations/r1'), { active: false }));
    await assertSucceeds(updateDoc(doc(paul(), 'conversations/r1'), { participants: ['awa'] }));
    await assertSucceeds(updateDoc(doc(awa(), 'conversations/r1'), { active: false }));
    await assertFails(setDoc(doc(awa(), 'conversations/r1/messages/late'), {
      senderId: 'awa', senderName: 'Awa', text: 'Trop tard', signed: false, createdAt: serverTimestamp(),
    }));
  });

  test('un compte suspendu ne peut plus écrire', async () => {
    await seed('users/awa', { name: 'Awa', role: 'user', suspended: true });
    await seed('conversations/r1', room);
    await assertFails(setDoc(doc(awa(), 'conversations/r1/messages/m1'), {
      senderId: 'awa', senderName: 'Awa', text: 'Hello', signed: false, createdAt: serverTimestamp(),
    }));
  });

  test('un participant invite par e-mail', async () => {
    await seed('conversations/r1', room);
    await assertSucceeds(updateDoc(doc(awa(), 'conversations/r1'), { invitedEmails: arrayUnion('new@test.com') }));
  });
});
