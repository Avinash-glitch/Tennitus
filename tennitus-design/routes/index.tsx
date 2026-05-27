import { createFileRoute, Link } from "@tanstack/react-router";
import { MobileFrame } from "@/components/MobileFrame";
import { BottomNav } from "@/components/BottomNav";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Today — Tennitus" },
      { name: "description", content: "Today's tinnitus pulse, 7-day trend, and quick actions." },
      { property: "og:title", content: "Today — Tennitus" },
      { property: "og:description", content: "Today's tinnitus pulse, 7-day trend, and quick actions." },
    ],
  }),
  component: TodayDashboard,
});

const trend = [40, 60, 30, 75, 90, 50, 45];
const trendDays = ["M", "T", "W", "T", "F", "S", "S"];

function TodayDashboard() {
  const now = new Date();
  const dateLabel = now.toLocaleDateString("en-US", {
    weekday: "long",
    month: "short",
    day: "numeric",
  });

  return (
    <MobileFrame>
      <div className="flex flex-col min-h-[calc(100vh-3rem)]">
        <main className="px-6 pt-2 pb-6 space-y-6 animate-slide-up">
          <header>
            <p className="text-[10px] font-mono text-accent uppercase tracking-[0.2em] mb-2">
              Profile · High Frequency · {dateLabel}
            </p>
            <h1 className="text-3xl font-extrabold tracking-tight text-balance">
              Today&rsquo;s Pulse.
            </h1>
          </header>

          {/* Primary status card */}
          <section className="glass rounded-3xl p-5 space-y-4">
            <div className="flex justify-between items-start">
              <div>
                <span className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground">
                  Distress Level
                </span>
                <div className="mt-1 flex items-baseline gap-1">
                  <span className="font-mono text-4xl text-warning">04</span>
                  <span className="font-mono text-xs text-muted-foreground">/10</span>
                </div>
              </div>
              <div>
                <span className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground">
                  Peak Hz
                </span>
                <div className="mt-1 font-mono text-lg text-foreground">
                  8,420 <span className="text-xs text-muted-foreground">Hz</span>
                </div>
              </div>
            </div>

            <div className="h-12 flex items-end gap-1.5">
              {[10, 18, 28, 42, 64, 38, 24, 18, 12].map((h, i) => (
                <div
                  key={i}
                  className={`flex-1 rounded-full ${
                    h > 60 ? "bg-warning" : "bg-zinc-800"
                  }`}
                  style={{ height: `${h}%` }}
                />
              ))}
            </div>

            <p className="text-xs text-muted-foreground leading-relaxed">
              Slightly elevated reactivity. Ambient office noise recorded at 62&nbsp;dB.
            </p>
          </section>

          {/* 7-day trend */}
          <section className="space-y-3">
            <div className="flex justify-between items-center">
              <h3 className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground">
                7-Day History
              </h3>
              <span className="text-[10px] font-mono text-accent">↓ TRENDING DOWN</span>
            </div>
            <div className="grid grid-cols-7 gap-2 h-24 items-end">
              {trend.map((h, i) => {
                const isToday = i === trend.length - 1;
                return (
                  <div key={i} className="flex flex-col items-center gap-1.5 h-full justify-end">
                    <div
                      className={`w-full rounded-sm ${
                        isToday ? "bg-accent" : "bg-accent/30"
                      }`}
                      style={{
                        height: `${h}%`,
                        boxShadow: isToday ? "0 0 12px var(--color-accent)" : undefined,
                      }}
                    />
                    <span
                      className={`text-[9px] font-mono ${
                        isToday ? "text-accent" : "text-muted-foreground"
                      }`}
                    >
                      {trendDays[i]}
                    </span>
                  </div>
                );
              })}
            </div>
          </section>

          {/* Quick actions */}
          <section className="grid grid-cols-2 gap-3">
            <Link
              to="/logger"
              className="glass rounded-2xl p-4 h-28 flex flex-col justify-between active:scale-[0.98] transition-transform"
            >
              <span className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground">
                Log Event
              </span>
              <div className="flex items-end justify-between">
                <div className="size-9 rounded-full bg-accent flex items-center justify-center shadow-[0_0_16px_var(--color-accent)]">
                  <div className="size-3 rounded-sm bg-background" />
                </div>
                <span className="text-[10px] font-mono text-muted-foreground">→</span>
              </div>
            </Link>
            <Link
              to="/lab"
              className="glass rounded-2xl p-4 h-28 flex flex-col justify-between active:scale-[0.98] transition-transform"
            >
              <span className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground">
                Tone Match
              </span>
              <div className="flex items-end justify-between">
                <div className="size-9 rounded-full border border-accent flex items-center justify-center">
                  <span className="font-mono text-[10px] text-accent">Hz</span>
                </div>
                <span className="text-[10px] font-mono text-muted-foreground">→</span>
              </div>
            </Link>
          </section>

          {/* Recent activity */}
          <section className="space-y-3">
            <h3 className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground">
              Recent Activity
            </h3>
            {[
              { env: "Outdoor", note: "Traffic noise", time: "13:30", level: "Moderate", tone: "warning" },
              { env: "Bedroom", note: "High ringing", time: "08:45", level: "Severe", tone: "destructive" },
            ].map((row) => (
              <div
                key={row.time}
                className="glass rounded-2xl p-4 flex items-center justify-between"
              >
                <div className="flex items-center gap-3">
                  <div className="size-10 rounded-xl bg-secondary flex items-center justify-center">
                    <span className="font-mono text-[10px] text-muted-foreground">
                      {row.env.slice(0, 3).toUpperCase()}
                    </span>
                  </div>
                  <div>
                    <p className="text-sm font-medium">{row.env} Environment</p>
                    <p className="text-[11px] text-muted-foreground font-mono">
                      {row.note} · {row.time}
                    </p>
                  </div>
                </div>
                <span
                  className={`text-xs font-mono ${
                    row.tone === "destructive" ? "text-destructive" : "text-warning"
                  }`}
                >
                  {row.level}
                </span>
              </div>
            ))}
          </section>
        </main>

        <div className="mt-auto">
          <BottomNav />
        </div>
      </div>
    </MobileFrame>
  );
}
