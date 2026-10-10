.pragma library

var ALBION_CLASS = "Albion-Online"

var DEFAULT_BINDS = [
  { trigger: "mouse:275", combo: "SHIFT+N", enabled: true }
]

var TRIGGER_PRESETS = [
  { value: "mouse:275", label: "Botón lateral abajo" },
  { value: "mouse:276", label: "Botón lateral arriba" },
  { value: "mouse:274", label: "Clic de la rueda" },
  { value: "custom", label: "Otra tecla…" }
]

// Hyprland modifier name -> physical key Albion needs to see held down.
var MOD_KEYS = {
  SHIFT: "Shift_L",
  CTRL: "Control_L",
  ALT: "Alt_L",
  SUPER: "Super_L"
}

var MOD_ALIASES = { CONTROL: "CTRL", WIN: "SUPER", META: "SUPER" }

function triggerLabel(trigger) {
  for (var i = 0; i < TRIGGER_PRESETS.length; i++) {
    if (TRIGGER_PRESETS[i].value === trigger) return TRIGGER_PRESETS[i].label
  }
  return trigger
}

function normalizeTrigger(text) {
  var t = String(text || "").trim()
  if (!/^[A-Za-z0-9_:]+( ?\+ ?[A-Za-z0-9_:]+)*$/.test(t)) return ""
  return t.replace(/ ?\+ ?/g, " + ")
}

// "shift + n" -> { mods: ["SHIFT"], key: "N", text: "SHIFT+N" }, or null.
function parseCombo(text) {
  var parts = String(text || "").split("+").map(function(p) { return p.trim() }).filter(function(p) { return p !== "" })
  if (parts.length === 0) return null

  var mods = []
  for (var i = 0; i < parts.length - 1; i++) {
    var m = parts[i].toUpperCase()
    m = MOD_ALIASES[m] || m
    if (!MOD_KEYS[m] || mods.indexOf(m) >= 0) return null
    mods.push(m)
  }

  var key = parts[parts.length - 1]
  if (!/^[A-Za-z0-9_]+$/.test(key)) return null
  if (key.length === 1) key = key.toUpperCase()

  return { mods: mods, key: key, text: mods.concat([key]).join("+") }
}

function sanitizeBinds(list) {
  if (!Array.isArray(list)) return []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var b = list[i] || {}
    var trigger = normalizeTrigger(b.trigger)
    var combo = parseCombo(b.combo)
    if (!trigger || !combo) continue
    out.push({ trigger: trigger, combo: combo.text, enabled: b.enabled !== false })
  }
  return out
}

function luaString(s) {
  return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
}

// Builds ~/.config/hypr/albion-binds.lua. Binds are only registered while an
// Albion window is focused, so the same buttons keep working normally elsewhere.
function generateLua(binds, enabled) {
  var rows = []
  var active = enabled ? sanitizeBinds(binds).filter(function(b) { return b.enabled }) : []
  for (var i = 0; i < active.length; i++) {
    var combo = parseCombo(active[i].combo)
    rows.push("  { trigger = " + luaString(active[i].trigger)
      + ", mods = { " + combo.mods.map(luaString).join(", ") + " }"
      + ", key = " + luaString(combo.key)
      + ", label = " + luaString(combo.text) + " },")
  }

  return [
    "-- Generado por el plugin Albion Binds (fcogarcia.albion-binds).",
    "-- No lo edites a mano: cámbialo desde el ícono de la barra.",
    "",
    "local ALBION_CLASS = " + luaString(ALBION_CLASS),
    "local DELAY_MS = 40",
    "",
    "local binds = {",
    rows.join("\n"),
    "}",
    "",
    "local MOD_KEYS = { SHIFT = \"Shift_L\", CTRL = \"Control_L\", ALT = \"Alt_L\", SUPER = \"Super_L\" }",
    "",
    "-- Albion (XWayland) ignora el modificador sintético: hay que presionar la",
    "-- tecla modificadora real, luego la tecla, y soltar en orden inverso.",
    "local function tap(bind)",
    "  local steps, held = {}, {}",
    "  for _, mod in ipairs(bind.mods) do",
    "    table.insert(steps, { MOD_KEYS[mod], table.concat(held, \" \"), \"down\" })",
    "    table.insert(held, mod)",
    "  end",
    "  local all = table.concat(held, \" \")",
    "  table.insert(steps, { bind.key, all, \"down\" })",
    "  table.insert(steps, { bind.key, all, \"up\" })",
    "  for i = #bind.mods, 1, -1 do",
    "    table.remove(held)",
    "    table.insert(steps, { MOD_KEYS[bind.mods[i]], table.concat(held, \" \"), \"up\" })",
    "  end",
    "",
    "  local function run(i)",
    "    local s = steps[i]",
    "    if not s then return end",
    "    hl.dispatch(hl.dsp.send_key_state({ key = s[1], mods = s[2], state = s[3] }))",
    "    if steps[i + 1] then",
    "      hl.timer(function() run(i + 1) end, { timeout = DELAY_MS, type = \"oneshot\" })",
    "    end",
    "  end",
    "  run(1)",
    "end",
    "",
    "local bound = false",
    "",
    "local function set_bound(on)",
    "  if on == bound then return end",
    "  bound = on",
    "  for _, bind in ipairs(binds) do",
    "    if on then",
    "      hl.bind(bind.trigger, function() tap(bind) end, { description = \"Albion: \" .. bind.label })",
    "    else",
    "      hl.unbind(bind.trigger)",
    "    end",
    "  end",
    "end",
    "",
    "local function refresh()",
    "  local window = hl.get_active_window()",
    "  set_bound(window ~= nil and window.class == ALBION_CLASS)",
    "end",
    "",
    "if #binds > 0 then",
    "  hl.on(\"window.active\", refresh)",
    "  refresh()",
    "end",
    ""
  ].join("\n")
}
