import { Link, useRouterState } from "@tanstack/react-router";

const items = [
  { to: "/", label: "Today" },
  { to: "/logger", label: "Logger" },
  { to: "/lab", label: "Lab" },
  { to: "/settings", label: "Profile" },
] as const;

export function BottomNav() {
  const { location } = useRouterState();
  const path = location.pathname;

  return (
    <nav className="sticky bottom-0 left-0 right-0 z-20 mt-8">
      <div className="mx-4 mb-4 rounded-2xl glass px-3 py-2 flex items-center justify-between">
        {items.map((item) => {
          const active = path === item.to;
          return (
            <Link
              key={item.to}
              to={item.to}
              className={`flex-1 flex flex-col items-center gap-1 py-2 rounded-xl transition-colors ${
                active ? "bg-white/5" : ""
              }`}
            >
              <span
                className={`size-1.5 rounded-full ${
                  active
                    ? "bg-accent shadow-[0_0_8px_var(--color-accent)]"
                    : "bg-zinc-700"
                }`}
              />
              <span
                className={`text-[10px] font-mono uppercase tracking-widest ${
                  active ? "text-accent" : "text-muted-foreground"
                }`}
              >
                {item.label}
              </span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
