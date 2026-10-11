.pragma library

// Independent module: it receives sanitizeBinds from the caller because QML
// script imports between .js files are not used by any stock plugin.

var EXPORT_APP = "albion-companion"
// Files written by the old plugin (fcogarcia.albion-binds) are still importable.
var LEGACY_APPS = ["albion-binds"]
var EXPORT_VERSION = 1

// sanitizeBinds is injected (Binds.sanitizeBinds).
// Serializes the binds for ~/albion-companion.json (pretty-printed, trailing newline).
function exportBinds(binds, enabled, sanitizeBinds) {
  return JSON.stringify({
    app: EXPORT_APP,
    version: EXPORT_VERSION,
    enabled: enabled !== false,
    binds: sanitizeBinds(binds)
  }, null, 2) + "\n"
}

// Parses an exported file (or a bare array of binds) into
// { ok: true, binds, enabled, skipped } or { ok: false, error }.
function parseImport(text, sanitizeBinds) {
  var data
  try {
    data = JSON.parse(text)
  } catch (e) {
    return { ok: false, error: "El archivo no es JSON válido." }
  }

  var list
  var enabled = true
  if (Array.isArray(data)) {
    list = data
  } else if (data !== null && typeof data === "object") {
    if (data.app !== undefined && data.app !== EXPORT_APP && LEGACY_APPS.indexOf(data.app) < 0)
      return { ok: false, error: "Este archivo no es un respaldo de Albion Companion." }
    if (data.version !== undefined && !(Number(data.version) <= EXPORT_VERSION))
      return { ok: false, error: "El archivo es de una versión más nueva de Albion Companion." }
    if (!Array.isArray(data.binds))
      return { ok: false, error: "El archivo no tiene una lista de atajos." }
    list = data.binds
    enabled = data.enabled !== false
  } else {
    return { ok: false, error: "El archivo no tiene el formato esperado." }
  }

  var seen = []
  var binds = []
  var valid = sanitizeBinds(list)
  for (var i = 0; i < valid.length; i++) {
    if (seen.indexOf(valid[i].trigger) >= 0) continue
    seen.push(valid[i].trigger)
    binds.push(valid[i])
  }

  if (list.length > 0 && binds.length === 0)
    return { ok: false, error: "El archivo no tiene atajos válidos." }

  return { ok: true, binds: binds, enabled: enabled, skipped: list.length - binds.length }
}
