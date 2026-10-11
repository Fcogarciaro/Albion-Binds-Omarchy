import { test } from "node:test"
import assert from "node:assert/strict"
import { existsSync, readFileSync } from "node:fs"

const manifest = JSON.parse(readFileSync(new URL("../manifest.json", import.meta.url), "utf8"))

test("manifest: renamed to Albion Companion with the new id and version", () => {
  assert.equal(manifest.id, "fcogarcia.albion-companion")
  assert.equal(manifest.name, "Albion Companion")
  assert.equal(manifest.barWidget.displayName, "Albion Companion")
  assert.equal(manifest.version, "2.0.0")
})

test("manifest: the bar widget entry point exists", () => {
  assert.equal(manifest.entryPoints.barWidget, "Panel.qml")
})

test("manifest: the large window is a panel entry point that exists", () => {
  assert.deepEqual(manifest.kinds, ["bar-widget", "panel"])
  assert.equal(manifest.entryPoints.panel, "Window.qml")
  assert.ok(existsSync(new URL("../" + manifest.entryPoints.panel, import.meta.url)))
})
