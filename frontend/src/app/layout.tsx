import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "StakingRewards — demo",
  description: "Demo UI del pool de staking O(1) estilo Synthetix",
};

/** Layout raíz (Server Component). */
export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body>
        <main className="shell">{children}</main>
      </body>
    </html>
  );
}
