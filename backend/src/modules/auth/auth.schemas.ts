import { z } from 'zod';

export const registrationSchema = z.object({
  firstName: z.string().trim().min(1).max(80),
  lastName: z.string().trim().min(1).max(80),
  birthDate: z.string().date(),
  email: z.string().trim().email().max(254),
  phone: z.string().trim().min(1).max(40),
  password: z.string().min(8).max(128),
  departmentId: z.string().uuid(),
  termsAccepted: z.literal(true),
  termsVersion: z.string().trim().min(1).max(32)
});
export const credentialsSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(1).max(128)
});
export const refreshSchema = z.object({ refreshToken: z.string().min(32).max(512) });
export const codeSchema = z.object({ code: z.string().regex(/^\d{6}$/) });
export const forgotPasswordSchema = z.object({ email: z.string().trim().email().max(254) });
export const resetSchema = forgotPasswordSchema.extend({
  code: z.string().regex(/^\d{6}$/),
  newPassword: z.string().min(8).max(128)
});
export const passwordSchema = z.object({
  currentPassword: z.string().min(1).max(128),
  newPassword: z.string().min(8).max(128)
});
export const deleteSchema = z.object({ password: z.string().min(1).max(128) });
export const profilePatchSchema = z
  .object({
    firstName: z.string().trim().min(1).max(80).optional(),
    lastName: z.string().trim().min(1).max(80).optional(),
    phone: z.string().trim().min(1).max(40).optional(),
    departmentId: z.string().uuid().optional()
  })
  .refine((value) => Object.keys(value).length > 0);
export const userIdParamsSchema = z.object({ id: z.string().uuid() });

const user = z.object({
  id: z.string().uuid(),
  firstName: z.string(),
  lastName: z.string(),
  birthDate: z.string(),
  email: z.string().email(),
  phone: z.string(),
  departmentId: z.string().uuid(),
  emailVerified: z.boolean()
});
const publicUser = z.object({
  id: z.string().uuid(),
  firstName: z.string(),
  lastNameInitial: z.string(),
  departmentId: z.string().uuid(),
  department: z.string(),
  ratingAverage: z.number().nullable(),
  ratingCount: z.number().int(),
  completedLessonsCount: z.number().int()
});
const tokens = z.object({ user, accessToken: z.string(), refreshToken: z.string() });
const error = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    details: z.record(z.string(), z.unknown()).optional()
  })
});
const none = z.null();
export const responses = {
  register: { 201: tokens, 400: error, 409: error, 422: error, 500: error },
  login: { 200: tokens, 400: error, 401: error, 429: error, 500: error },
  refresh: { 200: tokens, 400: error, 401: error, 500: error },
  logout: { 204: none, 400: error, 500: error },
  verify: { 204: none, 400: error, 401: error, 410: error, 429: error, 500: error },
  resend: { 204: none, 401: error, 429: error, 500: error },
  forgot: { 202: none, 400: error, 500: error },
  reset: { 204: none, 400: error, 410: error, 429: error, 500: error },
  me: { 200: user, 400: error, 401: error, 409: error, 500: error },
  publicUser: { 200: publicUser, 400: error, 404: error, 500: error },
  changePassword: { 204: none, 400: error, 401: error, 500: error },
  deleteMe: { 204: none, 400: error, 401: error, 409: error, 500: error }
} as const;
