import { describe, expect, it } from 'vitest';

import { mapDatabaseError } from './errors.js';

const businessCases = [
  ['REQUEST_NOT_FOUND', 404],
  ['USER_NOT_FOUND', 404],
  ['LISTING_NOT_FOUND', 404],
  ['NOT_LISTING_OWNER', 403],
  ['NOT_A_PARTICIPANT', 403],
  ['REVIEW_PARTIES_MISMATCH', 403],
  ['REQUEST_NOT_PENDING', 409],
  ['REQUEST_NOT_ACCEPTED', 409],
  ['LISTING_NOT_PUBLISHED', 409],
  ['LISTING_ALREADY_BOOKED', 409],
  ['TIME_CONFLICT', 409],
  ['REQUEST_NOT_SETTLEABLE', 409],
  ['USER_HAS_ACTIVE_OBLIGATIONS', 409],
  ['CONFIRMATION_TOO_EARLY', 409],
  ['CONFIRMATION_WINDOW_CLOSED', 409],
  ['LISTING_CORE_FIELDS_LOCKED', 409],
  ['LISTING_TEACHER_IMMUTABLE', 409],
  ['REVIEW_REQUIRES_COMPLETED_LESSON', 409],
  ['CONVERSATION_REQUIRES_ACCEPTED_REQUEST', 409],
  ['LISTING_EXPIRED', 409],
  ['INSUFFICIENT_BALANCE', 402],
  ['LISTING_START_IN_PAST', 422],
  ['COURSE_DEPARTMENT_MISMATCH', 422],
  ['COURSE_INACTIVE', 422],
  ['LOCATION_INACTIVE_OR_UNKNOWN', 422],
  ['TEACHER_ANONYMIZED', 422],
  ['LISTING_MUST_START_PUBLISHED', 422]
] as const;

describe('mapDatabaseError', () => {
  it.each(businessCases)('maps business code %s', (code, statusCode) => {
    const error = mapDatabaseError({ code: 'P0001', message: code });
    expect(error).toMatchObject({ code, statusCode });
  });

  it.each([['LEDGER_IS_APPEND_ONLY'], ['WALLET_INVALID_STATE']])(
    'does not expose internal wallet error %s',
    (message) => {
      expect(mapDatabaseError({ code: 'P0001', message })).toMatchObject({
        code: 'INTERNAL',
        statusCode: 500
      });
    }
  );

  it.each([
    ['users_email_uq', 409, 'EMAIL_TAKEN'],
    ['users_phone_uq', 409, 'PHONE_TAKEN'],
    ['lr_one_per_student_listing_uq', 409, 'ALREADY_REQUESTED'],
    ['lr_not_self_ck', 422, 'CANNOT_REQUEST_OWN_LISTING'],
    ['reviews_once_per_reviewer_uq', 409, 'ALREADY_REVIEWED']
  ])('maps constraint %s', (constraint, statusCode, code) => {
    expect(mapDatabaseError({ code: '23505', constraint })).toMatchObject({ statusCode, code });
  });

  it.each([
    ['23505', 409, 'CONSTRAINT_VIOLATION'],
    ['23514', 422, 'CONSTRAINT_VIOLATION'],
    ['23503', 409, 'CONSTRAINT_VIOLATION'],
    ['22P02', 400, 'BAD_REQUEST']
  ])('maps SQLSTATE %s', (dbCode, statusCode, code) => {
    expect(mapDatabaseError({ code: dbCode })).toMatchObject({ statusCode, code });
  });

  it('hides unknown database errors', () => {
    expect(mapDatabaseError({ code: 'XX000', message: 'sensitive detail' })).toMatchObject({
      code: 'INTERNAL',
      statusCode: 500
    });
  });
});
