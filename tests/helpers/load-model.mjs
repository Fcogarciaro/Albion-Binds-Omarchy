import { readFileSync } from "node:fs"
import vm from "node:vm"

const MODEL_PATH = new URL("../../Model.js", import.meta.url)

// Loads Model.js (a QML ".pragma library" script) into an isolated context.
export function loadModel() {
  const source = readFileSync(MODEL_PATH, "utf8").replace(/^\.pragma library\s*$/m, "")
  const context = vm.createContext({})
  vm.runInContext(source, context)
  return context
}

// Values created inside the vm context have foreign prototypes, which makes
// deepStrictEqual fail. A JSON round trip yields plain host-realm values.
export function plain(value) {
  return JSON.parse(JSON.stringify(value))
}
