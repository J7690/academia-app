import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  publishPostSchema,
  sendMessageSchema,
  insightsSchema,
} from '../src/modules/facebook/facebook.schemas.js';

describe('Facebook schemas', () => {
  it('accepte une publication valide', () => {
    const parsed = publishPostSchema.parse({ message: 'Bonjour' });
    assert.equal(parsed.message, 'Bonjour');
  });

  it('rejette une publication vide', () => {
    assert.throws(() => publishPostSchema.parse({ message: '' }));
  });

  it('exige un destinataire et un message', () => {
    assert.throws(() => sendMessageSchema.parse({ recipientId: '123' }));
    const ok = sendMessageSchema.parse({ recipientId: '123', message: 'Salut' });
    assert.equal(ok.recipientId, '123');
  });

  it('applique les valeurs par défaut des insights', () => {
    const parsed = insightsSchema.parse({});
    assert.equal(parsed.period, 'week');
    assert.ok(parsed.metrics.length > 0);
  });
});
