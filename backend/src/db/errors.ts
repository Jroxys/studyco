import { AppError, internalError } from '../errors.js';

interface DatabaseError {
  code?: string;
  constraint?: string;
  message?: string;
}

const businessStatuses: Record<string, number> = {
  REQUEST_NOT_FOUND: 404,
  USER_NOT_FOUND: 404,
  LISTING_NOT_FOUND: 404,
  NOT_LISTING_OWNER: 403,
  NOT_A_PARTICIPANT: 403,
  REVIEW_PARTIES_MISMATCH: 403,
  REQUEST_NOT_PENDING: 409,
  REQUEST_NOT_ACCEPTED: 409,
  LISTING_NOT_PUBLISHED: 409,
  LISTING_ALREADY_BOOKED: 409,
  TIME_CONFLICT: 409,
  REQUEST_NOT_SETTLEABLE: 409,
  USER_HAS_ACTIVE_OBLIGATIONS: 409,
  CONFIRMATION_TOO_EARLY: 409,
  CONFIRMATION_WINDOW_CLOSED: 409,
  LISTING_CORE_FIELDS_LOCKED: 409,
  LISTING_TEACHER_IMMUTABLE: 409,
  REVIEW_REQUIRES_COMPLETED_LESSON: 409,
  CONVERSATION_REQUIRES_ACCEPTED_REQUEST: 409,
  LISTING_EXPIRED: 409,
  INSUFFICIENT_BALANCE: 402,
  LISTING_START_IN_PAST: 422,
  COURSE_DEPARTMENT_MISMATCH: 422,
  COURSE_INACTIVE: 422,
  LOCATION_INACTIVE_OR_UNKNOWN: 422,
  TEACHER_ANONYMIZED: 422,
  LISTING_MUST_START_PUBLISHED: 422
};

const constraintErrors: Record<string, AppError> = {
  users_email_uq: new AppError(409, 'EMAIL_TAKEN', 'Email is already registered'),
  users_phone_uq: new AppError(409, 'PHONE_TAKEN', 'Phone is already registered'),
  lr_one_per_student_listing_uq: new AppError(
    409,
    'ALREADY_REQUESTED',
    'A request already exists for this listing'
  ),
  lr_not_self_ck: new AppError(
    422,
    'CANNOT_REQUEST_OWN_LISTING',
    'You cannot request your own listing'
  ),
  reviews_once_per_reviewer_uq: new AppError(
    409,
    'ALREADY_REVIEWED',
    'You have already reviewed this lesson'
  )
};

export function mapDatabaseError(error: unknown): AppError {
  const dbError = error as DatabaseError;

  if (dbError.code === 'P0001') {
    if (dbError.message?.startsWith('WALLET_') || dbError.message === 'LEDGER_IS_APPEND_ONLY') {
      return internalError();
    }

    const message = dbError.message;
    const statusCode = message === undefined ? undefined : businessStatuses[message];
    return message === undefined || statusCode === undefined
      ? internalError()
      : new AppError(statusCode, message, message.replaceAll('_', ' ').toLowerCase());
  }

  const constraintError =
    dbError.constraint === undefined ? undefined : constraintErrors[dbError.constraint];
  if (constraintError !== undefined) {
    return constraintError;
  }

  if (dbError.code === '23505') {
    return new AppError(409, 'CONSTRAINT_VIOLATION', 'A uniqueness constraint was violated');
  }
  if (dbError.code === '23514') {
    return new AppError(422, 'CONSTRAINT_VIOLATION', 'A data constraint was violated');
  }
  if (dbError.code === '23503') {
    return new AppError(409, 'CONSTRAINT_VIOLATION', 'A related resource does not exist');
  }
  if (dbError.code === '22P02') {
    return new AppError(400, 'BAD_REQUEST', 'Invalid request value');
  }
  if (dbError.code === '22007' || dbError.code === '22008') {
    return new AppError(400, 'BAD_CURSOR', 'Invalid cursor');
  }

  return internalError();
}
