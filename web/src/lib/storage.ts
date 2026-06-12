import { supabase } from "./supabase";

/**
 * The `documents` and `contracts` buckets are private. Database rows keep the
 * public-style URL (it encodes bucket + path); anything that opens a file
 * resolves it to a short-lived signed URL first. URLs outside the private
 * buckets (catalog images, external links) pass through unchanged.
 */
const PRIVATE_BUCKETS: ReadonlySet<string> = new Set(["documents", "contracts"]);

const SIGNED_URL_LIFETIME_SECONDS = 3600;

interface StorageObjectRef {
  bucket: string;
  path: string;
}

interface CachedSignedUrl {
  url: string;
  expiresAt: number;
}

const signedUrlCache = new Map<string, CachedSignedUrl>();

/** Extracts bucket + object path from a Supabase storage object URL. */
export function parseStorageObject(url: string): StorageObjectRef | null {
  const markers = ["/storage/v1/object/public/", "/storage/v1/object/sign/"];
  for (const marker of markers) {
    const idx = url.indexOf(marker);
    if (idx === -1) continue;
    const rest = url.slice(idx + marker.length);
    const slash = rest.indexOf("/");
    if (slash === -1) continue;
    const bucket = rest.slice(0, slash);
    const rawPath = rest.slice(slash + 1).split("?")[0] ?? "";
    if (!bucket || !rawPath) continue;
    let path: string;
    try {
      path = decodeURIComponent(rawPath);
    } catch {
      path = rawPath;
    }
    return { bucket, path };
  }
  return null;
}

/**
 * Resolves a stored URL to an openable one. Returns a signed URL for
 * private-bucket objects, the original URL otherwise. Falls back to the
 * original URL on signing failure so links never dead-end.
 */
export async function resolveStorageUrl(url: string | null | undefined): Promise<string | null> {
  if (!url) return null;
  const ref = parseStorageObject(url);
  if (!ref || !PRIVATE_BUCKETS.has(ref.bucket)) return url;

  const cached = signedUrlCache.get(url);
  if (cached && cached.expiresAt > Date.now()) return cached.url;

  const { data, error } = await supabase.storage
    .from(ref.bucket)
    .createSignedUrl(ref.path, SIGNED_URL_LIFETIME_SECONDS);
  if (error || !data?.signedUrl) {
    console.error("[storage] Failed to sign URL", { bucket: ref.bucket, path: ref.path, error: error?.message });
    return url;
  }
  signedUrlCache.set(url, {
    url: data.signedUrl,
    expiresAt: Date.now() + (SIGNED_URL_LIFETIME_SECONDS - 300) * 1000,
  });
  return data.signedUrl;
}

/**
 * Opens a stored file URL in a new tab, resolving private-bucket objects to
 * signed URLs. Opens the tab synchronously so popup blockers don't eat it.
 */
export function openStorageUrl(url: string | null | undefined): void {
  if (!url) return;
  const win = window.open("about:blank", "_blank");
  void resolveStorageUrl(url).then((resolved) => {
    if (!resolved) {
      win?.close();
      return;
    }
    if (win) {
      win.location.href = resolved;
    } else {
      window.location.assign(resolved);
    }
  });
}
