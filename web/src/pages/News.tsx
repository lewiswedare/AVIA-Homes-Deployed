import { ArrowLeft, Newspaper } from "lucide-react";
import { useMemo } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";

import { BentoCard, EmptyState, Spinner } from "@/components/avia/ui";
import { CoverImage } from "@/components/catalog/shared";
import { fmtDate } from "@/lib/format";
import { useBlogPosts } from "@/lib/queries";

/** News — /news lists blog posts, /news/:id shows the article (iOS AllNewsView parity). */
export default function News() {
  const { id } = useParams<{ id?: string }>();
  const postsQ = useBlogPosts();

  if (postsQ.isLoading) return <Spinner />;
  if (id) return <Article id={id} />;

  const posts = postsQ.data ?? [];

  return (
    <div className="animate-fade-in space-y-5">
      <div>
        <h1 className="text-[26px] font-medium text-avia-black">Latest News</h1>
        <p className="text-[13px] text-avia-black/50">Stories, updates and inspiration from AVIA Homes</p>
      </div>
      {posts.length === 0 ? (
        <EmptyState icon={Newspaper} title="No news yet" subtitle="Check back soon for updates." />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {posts.map((post) => (
            <Link key={post.id} to={`/news/${encodeURIComponent(post.id)}`} className="block">
              <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
                <CoverImage src={post.image_url} alt={post.title} className="h-40">
                  <span className="absolute left-3 top-3 rounded-full bg-avia-black/50 px-2.5 py-0.5 text-[10px] font-medium uppercase tracking-wide text-white backdrop-blur">
                    {post.category}
                  </span>
                </CoverImage>
                <div className="space-y-1 p-4">
                  <div className="line-clamp-2 text-[15px] font-medium text-avia-black">{post.title}</div>
                  <div className="line-clamp-2 text-[13px] text-avia-black/55">{post.subtitle}</div>
                  <div className="text-[11px] text-avia-black/40">
                    {post.read_time} · {fmtDate(post.date)}
                  </div>
                </div>
              </BentoCard>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

function Article({ id }: { id: string }) {
  const navigate = useNavigate();
  const postsQ = useBlogPosts();
  const post = useMemo(() => (postsQ.data ?? []).find((p) => p.id === id) ?? null, [postsQ.data, id]);

  if (!post) return <EmptyState icon={Newspaper} title="Article not found" />;

  return (
    <div className="animate-fade-in space-y-5">
      <button
        type="button"
        onClick={() => navigate(-1)}
        className="flex items-center gap-1.5 text-[13px] font-medium text-avia-black/55 transition-colors hover:text-avia-black"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>
      <BentoCard className="overflow-hidden">
        <CoverImage src={post.image_url} alt={post.title} className="h-56 sm:h-72" />
        <div className="space-y-3 p-5 sm:p-7">
          <span className="rounded-full bg-avia-brown/10 px-2.5 py-0.5 text-[11px] font-medium uppercase tracking-wide text-avia-brown">
            {post.category}
          </span>
          <h1 className="text-[26px] font-medium leading-tight text-avia-black">{post.title}</h1>
          <div className="text-[12px] text-avia-black/45">
            {post.read_time} · {fmtDate(post.date)}
          </div>
          <p className="text-[15px] leading-relaxed text-avia-black/70">{post.subtitle}</p>
          <div className="space-y-4 border-t border-avia-line/60 pt-4 text-[14px] leading-relaxed text-avia-black/75">
            {post.content.split(/\n\n+/).map((para, i) => (
              <p key={i}>{para}</p>
            ))}
          </div>
        </div>
      </BentoCard>
    </div>
  );
}
