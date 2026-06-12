import { Bath, BedDouble, Car, ChevronRight, Instagram, MapPin, Newspaper } from "lucide-react";
import { useMemo } from "react";
import { Link } from "react-router-dom";

import { BentoCard } from "@/components/avia/ui";
import { CoverImage } from "@/components/catalog/shared";
import { useAuth } from "@/hooks/useAuth";
import {
  DISCOVER_HERO_IMAGE,
  SPEC_TIER_FALLBACK_HERO,
  responseFor,
  visiblePackages,
} from "@/lib/catalog";
import { fmtDate } from "@/lib/format";
import {
  useBlogPosts,
  useFacades,
  useHomeDesigns,
  usePackageAssignments,
  usePackages,
  useSpecRangeTiers,
} from "@/lib/queries";
import { RESPONSE_ACCEPTED, RESPONSE_PENDING, SPEC_TIERS, specTierLabel, specTierTagline } from "@/lib/types";

/**
 * Discover dashboard for clients without a build — mirrors the iOS
 * ClientDiscoverDashboardView (hero, greeting, DiscoverFeedView sections).
 */
export default function DiscoverDashboard() {
  const { profile } = useAuth();
  const name = profile?.first_name ?? "";

  return (
    <div className="animate-fade-in space-y-6">
      <BentoCard className="overflow-hidden">
        <CoverImage src={DISCOVER_HERO_IMAGE} alt="AVIA Homes" className="h-56 sm:h-72">
          <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-avia-black/70 to-transparent p-5 pt-20">
            <img src="/brand/avia-logo.png" alt="" className="h-6 w-auto brightness-0 invert" />
            <h1 className="mt-2 text-[30px] font-medium leading-tight text-white">
              Welcome Home{name ? `, ${name}` : ""}
            </h1>
            <p className="text-[13px] text-white/75">Explore designs, packages and inspiration for your future build.</p>
          </div>
        </CoverImage>
      </BentoCard>

      <DiscoverFeed />
    </div>
  );
}

/** Shared discover feed — Shared With You, News, Designs, Spec Ranges, Facades, Social. */
export function DiscoverFeed() {
  const { role, userId } = useAuth();
  const packagesQ = usePackages();
  const assignmentsQ = usePackageAssignments();
  const postsQ = useBlogPosts();
  const designsQ = useHomeDesigns();
  const facadesQ = useFacades();
  const tiersQ = useSpecRangeTiers();

  const shared = useMemo(
    () => visiblePackages(role, userId, packagesQ.data, assignmentsQ.data),
    [role, userId, packagesQ.data, assignmentsQ.data],
  );
  const pendingCount = useMemo(
    () =>
      shared.filter((p) => {
        const a = (assignmentsQ.data ?? []).find((x) => x.package_id === p.id) ?? null;
        const resp = responseFor(a, userId);
        return !resp || resp.status === RESPONSE_PENDING;
      }).length,
    [shared, assignmentsQ.data, userId],
  );

  const posts = postsQ.data ?? [];
  const featured = posts[0] ?? null;
  const designs = (designsQ.data ?? []).slice(0, 6);
  const facades = facadesQ.data ?? [];

  return (
    <div className="space-y-7">
      {/* Shared with you */}
      {shared.length > 0 && (
        <section className="space-y-2.5">
          <div className="flex items-center justify-between">
            <FeedHeader title="Shared With You" />
            {pendingCount > 0 && (
              <span className="rounded-full bg-avia-brown px-2.5 py-0.5 text-[11px] font-medium text-white">
                {pendingCount} new
              </span>
            )}
          </div>
          <BentoCard className="divide-y divide-avia-line/60 px-4">
            {shared.slice(0, 3).map((pkg) => {
              const a = (assignmentsQ.data ?? []).find((x) => x.package_id === pkg.id) ?? null;
              const resp = responseFor(a, userId);
              const pending = !resp || resp.status === RESPONSE_PENDING;
              return (
                <Link key={pkg.id} to={`/packages/${encodeURIComponent(pkg.id)}`} className="flex items-center gap-3 py-3">
                  <CoverImage src={pkg.image_url} alt={pkg.title} className="h-[72px] w-[72px] shrink-0 rounded-[10px]" />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[14px] font-medium text-avia-black">{pkg.title}</div>
                    <div className="flex items-center gap-1 text-[12px] text-avia-black/50">
                      <MapPin className="h-3 w-3" /> <span className="truncate">{pkg.location}</span>
                    </div>
                    <div className="text-[13px] font-semibold text-avia-brown">{pkg.price}</div>
                  </div>
                  {pending ? (
                    <span className="rounded-full bg-avia-brown px-2 py-0.5 text-[10px] font-semibold uppercase text-white">New</span>
                  ) : (
                    <span className={resp?.status === RESPONSE_ACCEPTED ? "text-green-700" : "text-red-700"}>
                      <ChevronRight className="h-4 w-4" />
                    </span>
                  )}
                </Link>
              );
            })}
            {shared.length > 3 && (
              <Link to="/my-package" className="flex items-center justify-center gap-1 py-3 text-[13px] font-medium text-avia-brown">
                View all {shared.length} packages <ChevronRight className="h-4 w-4" />
              </Link>
            )}
          </BentoCard>
        </section>
      )}

      {/* Latest news */}
      {posts.length > 0 && featured && (
        <section className="space-y-2.5">
          <div className="flex items-center justify-between">
            <FeedHeader title="Latest News" />
            <Link to="/news" className="text-[12px] font-medium text-avia-brown">
              See All
            </Link>
          </div>
          <Link to={`/news/${encodeURIComponent(featured.id)}`} className="block">
            <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
              <CoverImage src={featured.image_url} alt={featured.title} className="h-44">
                <span className="absolute left-3 top-3 rounded-full bg-avia-black/50 px-2.5 py-0.5 text-[10px] font-medium uppercase tracking-wide text-white backdrop-blur">
                  {featured.category}
                </span>
              </CoverImage>
              <div className="space-y-1 p-4">
                <div className="text-[15px] font-medium text-avia-black">{featured.title}</div>
                <div className="line-clamp-2 text-[13px] text-avia-black/55">{featured.subtitle}</div>
                <div className="text-[11px] text-avia-black/40">
                  {featured.read_time} · {fmtDate(featured.date)}
                </div>
              </div>
            </BentoCard>
          </Link>
          {posts.slice(1, 3).map((post) => (
            <Link key={post.id} to={`/news/${encodeURIComponent(post.id)}`} className="block">
              <BentoCard className="flex items-center gap-3 p-3 transition-colors hover:bg-avia-cardAlt">
                <CoverImage src={post.image_url} alt={post.title} className="h-14 w-14 shrink-0 rounded-[10px]" />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13px] font-medium text-avia-black">{post.title}</div>
                  <div className="text-[11px] text-avia-black/45">
                    {post.category} · {fmtDate(post.date)}
                  </div>
                </div>
                <Newspaper className="h-4 w-4 shrink-0 text-avia-black/30" />
              </BentoCard>
            </Link>
          ))}
        </section>
      )}

      {/* Our designs */}
      {designs.length > 0 && (
        <section className="space-y-2.5">
          <FeedHeader title="Our Designs" />
          <div className="scrollbar-none -mx-1 flex gap-3 overflow-x-auto px-1 pb-1">
            {designs.map((d) => (
              <Link key={d.id} to={`/designs/${encodeURIComponent(d.id)}`} className="w-60 shrink-0">
                <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
                  <CoverImage src={d.image_url} alt={d.name} className="h-40">
                    {d.storeys === 2 && (
                      <span className="absolute left-2.5 top-2.5 rounded-full bg-avia-black/50 px-2 py-0.5 text-[9px] font-medium uppercase text-white backdrop-blur">
                        2 Storey
                      </span>
                    )}
                  </CoverImage>
                  <div className="space-y-1.5 p-3">
                    <div className="text-[14px] font-medium text-avia-black">{d.name}</div>
                    <div className="flex items-center gap-2.5 text-[11px] text-avia-black/55">
                      <span className="flex items-center gap-1"><BedDouble className="h-3 w-3" />{d.bedrooms}</span>
                      <span className="flex items-center gap-1"><Bath className="h-3 w-3" />{d.bathrooms}</span>
                      <span className="flex items-center gap-1"><Car className="h-3 w-3" />{d.garages}</span>
                      <span>{Math.round(d.square_meters)}m²</span>
                    </div>
                  </div>
                </BentoCard>
              </Link>
            ))}
          </div>
        </section>
      )}

      {/* Spec ranges */}
      <section className="space-y-2.5">
        <div className="flex items-center justify-between">
          <FeedHeader title="Our Spec Ranges" />
          <Link to="/spec-ranges" className="text-[12px] font-medium text-avia-brown">
            Compare
          </Link>
        </div>
        <div className="grid gap-3 lg:grid-cols-3">
          {SPEC_TIERS.map((tier) => {
            const row = (tiersQ.data ?? []).find((r) => r.tier === tier) ?? null;
            return (
              <Link key={tier} to={`/spec-ranges/${tier}`} className="block">
                <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
                  <CoverImage src={row?.hero_image_url ?? SPEC_TIER_FALLBACK_HERO[tier]} alt={specTierLabel[tier]} className="h-48">
                    <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-avia-black/75 to-transparent p-4 pt-12">
                      <div className="text-[18px] font-medium text-white">{specTierLabel[tier]}</div>
                      <div className="text-[12px] text-white/70">{specTierTagline[tier]}</div>
                      <span className="mt-1.5 inline-flex items-center gap-1 rounded-full bg-white/15 px-2.5 py-0.5 text-[11px] font-medium text-white backdrop-blur">
                        Explore {specTierLabel[tier]} <ChevronRight className="h-3 w-3" />
                      </span>
                    </div>
                  </CoverImage>
                </BentoCard>
              </Link>
            );
          })}
        </div>
      </section>

      {/* Our facades */}
      {facades.length > 0 && (
        <section className="space-y-2.5">
          <FeedHeader title="Our Facades" />
          <div className="scrollbar-none -mx-1 flex gap-3 overflow-x-auto px-1 pb-1">
            {facades.map((f) => (
              <Link key={f.id} to={`/facades/${encodeURIComponent(f.id)}`} className="w-72 shrink-0">
                <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
                  <CoverImage src={f.hero_image_url} alt={f.name} className="h-44">
                    <span className="absolute right-2.5 top-2.5 rounded-full bg-white/85 px-2 py-0.5 text-[10px] font-medium text-avia-brown backdrop-blur">
                      {f.pricing_type === "upgrade" ? "Upgrade" : "Included"}
                    </span>
                  </CoverImage>
                  <div className="p-3">
                    <div className="text-[14px] font-medium text-avia-black">{f.name}</div>
                    {f.style && <div className="text-[11px] text-avia-black/50">{f.style}</div>}
                  </div>
                </BentoCard>
              </Link>
            ))}
          </div>
        </section>
      )}

      {/* Stay social */}
      <section className="space-y-2.5">
        <FeedHeader title="Stay Social" />
        <a href="https://www.instagram.com/aviahomes" target="_blank" rel="noreferrer" className="block">
          <BentoCard className="flex items-center gap-4 bg-gradient-to-br from-avia-black to-avia-brown p-5 transition-transform hover:-translate-y-0.5">
            <div className="flex h-11 w-11 items-center justify-center rounded-full bg-white/15 text-white">
              <Instagram className="h-5 w-5" />
            </div>
            <div className="flex-1">
              <div className="text-[15px] font-medium text-white">@aviahomes</div>
              <div className="text-[12px] text-white/70">Follow our latest builds & inspiration on Instagram</div>
            </div>
            <ChevronRight className="h-4 w-4 text-white/60" />
          </BentoCard>
        </a>
      </section>
    </div>
  );
}

function FeedHeader({ title }: { title: string }) {
  return <h2 className="text-[11px] font-medium uppercase tracking-[0.12em] text-avia-black/40">{title}</h2>;
}
