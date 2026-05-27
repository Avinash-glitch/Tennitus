import type { ReactNode } from "react";

interface MobileFrameProps {
  children: ReactNode;
  statusLeft?: ReactNode;
  statusRight?: ReactNode;
}

/**
 * iOS-style phone frame. Acts as a viewport for in-app screens.
 * On mobile devices we fill the screen; on larger we render the rounded device.
 */
export function MobileFrame({ children, statusLeft, statusRight }: MobileFrameProps) {
  return (
    <div className="min-h-screen w-full bg-background flex items-start justify-center md:p-10">
      <div className="relative w-full md:max-w-[420px] md:aspect-[9/19.5] md:rounded-[48px] md:ring-8 md:ring-zinc-900 md:shadow-[0_30px_80px_-20px_rgba(0,0,0,0.8)] bg-background overflow-hidden grain">
        <div className="absolute inset-0 pointer-events-none bg-[radial-gradient(ellipse_at_top_right,oklch(0.82_0.135_198/0.06),transparent_60%)]" />
        <div className="absolute inset-0 pointer-events-none bg-[radial-gradient(ellipse_at_bottom_left,oklch(0.78_0.16_70/0.04),transparent_55%)]" />

        {/* Status bar */}
        <div className="relative h-12 flex items-center justify-between px-8 text-[10px] font-mono tracking-widest text-muted-foreground z-10">
          <span>{statusLeft ?? "TNNTS_SYS_v4.2"}</span>
          <span>{statusRight ?? "12:44"}</span>
        </div>

        <div className="relative z-10">{children}</div>
      </div>
    </div>
  );
}
