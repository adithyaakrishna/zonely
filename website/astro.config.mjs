import { defineConfig } from "astro/config";

import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://zonely.adikris.in",
  outDir: "./site-dist",
  integrations: [sitemap()],
});