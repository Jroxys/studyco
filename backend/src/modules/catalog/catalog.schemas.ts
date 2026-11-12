import { z } from 'zod';

const error = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    details: z.record(z.string(), z.unknown()).optional()
  })
});
const department = z.object({ id: z.string().uuid(), name: z.string() });
const course = z.object({
  id: z.string().uuid(),
  departmentId: z.string().uuid(),
  name: z.string()
});
const location = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  latitude: z.number().nullable(),
  longitude: z.number().nullable()
});

export const departmentParamsSchema = z.object({ id: z.string().uuid() });
export const coursesQuerySchema = z.object({ departmentId: z.string().uuid().optional() });
export const catalogResponses = {
  departments: { 200: z.array(department), 500: error },
  courses: { 200: z.array(course), 400: error, 401: error, 500: error },
  locations: { 200: z.array(location), 401: error, 500: error }
} as const;
