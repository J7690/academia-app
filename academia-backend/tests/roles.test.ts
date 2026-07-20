import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { isRole, ROLES } from '../src/auth/roles.js';

describe('Rôles', () => {
  it('reconnaît les rôles valides', () => {
    for (const r of ROLES) assert.ok(isRole(r));
  });

  it('rejette les valeurs inconnues', () => {
    assert.equal(isRole('root'), false);
    assert.equal(isRole(42), false);
    assert.equal(isRole(undefined), false);
  });
});
