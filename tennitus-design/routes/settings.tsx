import { createFileRoute } from "@tanstack/react-router";
import { MobileFrame } from "@/components/MobileFrame";
import { BottomNav } from "@/components/BottomNav";

export const Route = createFileRoute("/settings")({
  head: () => ({
    meta: [
      { title: "Profile — Tennitus" },
      { name: "description", content: "Manage your tinnitus profile and Apple Health connections." },
      { property: "og:title", content: "Profile — Tennitus" },
      { property: "og:description", content: "Manage your tinnitus profile and Apple Health connections." },
    ],
  }),
  component: Settings,
});

const rows = [
  { label: "Tinnitus Profile", value: "High Frequency · 8.4 kHz", muted: false },
  { label: "Audiogram", value: "Imported · 12 Sep", muted: false },
  { label: "Apple Health Sleep", value: "Connected", muted: false },
  { label: "Daily Reminder", value: "21:00", muted: false },
  { label: "Export Data", value: "CSV · JSON", muted: true },
  { label: "About Tennitus", value: "v4.2.1", muted: true },
];

function Settings() {
  return (
    <MobileFrame statusLeft={<span>PROFILE</span>} statusRight={<span>12:44</span>}>
      <div className="flex flex-col min-h-[calc(100vh-3rem)]">
        <main className="px-6 pt-2 pb-6 space-y-6 animate-slide-up">
          <header>
            <p className="text-[10px] font-mono uppercase tracking-[0.2em] text-accent mb-2">
              Account · Local-Only
            </p>
            <h1 className="text-2xl font-bold tracking-tight">Alex Morgan</h1>
            <p className="text-sm text-muted-foreground mt-1 font-mono">14 day streak · 42 events</p>
          </header>

          <section className="glass rounded-3xl divide-y divide-border overflow-hidden">
            {rows.map((row) => (
              <div key={row.label} className="flex items-center justify-between p-4">
                <span className="text-sm">{row.label}</span>
                <span
                  className={`text-xs font-mono ${
                    row.muted ? "text-muted-foreground" : "text-foreground"
                  }`}
                >
                  {row.value}
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
