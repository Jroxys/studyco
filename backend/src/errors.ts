export type ErrorDetails = Record<string, unknown>;

export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly details: ErrorDetails | undefined;

  public constructor(statusCode: number, code: string, message: string, details?: ErrorDetails) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}

export function internalError(): AppError {
  return new AppError(500, 'INTERNAL', 'An unexpected error occurred');
}
