import { z } from "zod";

/** Shared zod schemas + a tiny helper for inline, per-field form errors. */

export const emailField = z
  .string()
  .trim()
  .min(1, "Please enter your email.")
  .email("Please enter a valid email address.");

export const newPasswordField = z.string().min(8, "Password must be at least 8 characters.");

export const nameField = z
  .string()
  .trim()
  .min(1, "This field is required.")
  .max(80, "Please use 80 characters or fewer.");

export const phoneField = z
  .string()
  .trim()
  .max(25, "That phone number looks too long.")
  .refine((v) => v === "" || /^[+()\-\s\d]{6,25}$/.test(v), "Please enter a valid phone number.");

export const loginSchema = z.object({
  email: emailField,
  password: z.string().min(1, "Please enter your password."),
});

export const signUpSchema = z
  .object({
    firstName: nameField,
    lastName: nameField,
    phone: phoneField,
    email: emailField,
    password: newPasswordField,
    confirm: z.string(),
  })
  .refine((v) => v.password === v.confirm, {
    message: "Passwords do not match.",
    path: ["confirm"],
  });

export const forgotPasswordSchema = z.object({ email: emailField });

export const resetPasswordSchema = z
  .object({
    password: newPasswordField,
    confirm: z.string(),
  })
  .refine((v) => v.password === v.confirm, {
    message: "Passwords do not match.",
    path: ["confirm"],
  });

export const profileSchema = z.object({
  firstName: nameField,
  lastName: nameField,
  phone: phoneField,
  address: z.string().trim().max(200, "Please use 200 characters or fewer."),
});

export type FieldErrors = Record<string, string>;

/**
 * Runs a zod schema and flattens issues into a `{ field: firstMessage }` map
 * for inline display. Returns parsed data on success.
 */
export function validate<T extends z.ZodTypeAny>(
  schema: T,
  values: unknown,
): { data: z.infer<T>; errors: null } | { data: null; errors: FieldErrors } {
  const result = schema.safeParse(values);
  if (result.success) return { data: result.data as z.infer<T>, errors: null };
  const errors: FieldErrors = {};
  for (const issue of result.error.issues) {
    const key = String(issue.path[0] ?? "form");
    if (!errors[key]) errors[key] = issue.message;
  }
  return { data: null, errors };
}
