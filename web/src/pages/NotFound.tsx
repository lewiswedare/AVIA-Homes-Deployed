import { Link } from "react-router-dom";

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-5 bg-avia-white px-6 text-center">
      <img src="/brand/avia-logo.png" alt="AVIA Homes" className="h-8 w-auto opacity-70" />
      <div>
        <div className="text-[40px] font-medium text-avia-brown">404</div>
        <p className="text-[14px] text-avia-black/55">This page doesn&apos;t exist.</p>
      </div>
      <Link
        to="/"
        className="rounded-full border border-avia-brown/30 px-5 py-2.5 text-[14px] font-medium text-avia-brown transition-colors hover:bg-avia-brown/10"
      >
        Back to Home
      </Link>
    </div>
  );
}
