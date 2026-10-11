import { readFileSync } from "node:fs"
import vm from "node:vm"

// Loads a QML ".pragma library" script (path relative to the repo root) into
// an isolated context. Modules are independent: none imports another.
export function loadModule(relPath) {
  const source = readFileSync(new URL(`../../${relPath}`, import.meta.url), "utf8").replace(/^\.pragma library\s*$/m, "")
  const context = vm.createContext({})
  vm.runInContext(source, context)
  return context
}

export const loadBinds = () => loadModule("binds/Binds.js")
export const loadBackup = () => loadModule("backup/Backup.js")
export const loadStorage = () => loadModule("shared/Storage.js")
export const loadFarm = () => loadModule("farm/Farm.js")
export const loadPrices = () => loadModule("farm/Prices.js")

// Values created inside the vm context have foreign prototypes, which makes
// deepStrictEqual fail. A JSON round trip yields plain host-realm values.
export function plain(value) {
  return JSON.parse(JSON.stringify(value))
}
