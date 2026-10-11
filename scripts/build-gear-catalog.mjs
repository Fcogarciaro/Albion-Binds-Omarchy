// Regenerates blackzone/GearCatalog.js from ao-bin-dumps (npm run build:catalog).
// Usage: node scripts/build-gear-catalog.mjs [path/to/items.json]
// Without an argument the 24 MB dump is downloaded to the OS temp folder
// (never into the repository).
import { mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { buildCatalog, renderCatalogModule } from "./gear-catalog.mjs"

const URL_ITEMS = "https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/formatted/items.json"
const output = new URL("../blackzone/GearCatalog.js", import.meta.url)

async function load(arg) {
  if (arg) return JSON.parse(readFileSync(arg, "utf8"))
  const dir = join(tmpdir(), "albion-companion")
  mkdirSync(dir, { recursive: true })
  const res = await fetch(URL_ITEMS)
  if (!res.ok) throw new Error("download failed: HTTP " + res.status)
  const text = await res.text()
  writeFileSync(join(dir, "items.json"), text)
  return JSON.parse(text)
}

const catalog = buildCatalog(await load(process.argv[2]))
writeFileSync(output, renderCatalogModule(catalog))
console.log(`${catalog.length} entries, ${statSync(output).size} bytes -> blackzone/GearCatalog.js`)
