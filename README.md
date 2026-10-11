# ⚔️ Albion Binds

Plugin para la barra de **Omarchy** que te deja asignar atajos a los botones del mouse
(o a cualquier tecla) que **solo funcionan dentro de Albion Online**.

Cuando no estás en el juego, los botones siguen haciendo lo de siempre
(por ejemplo, el botón lateral sigue siendo "Atrás" en el navegador).

Ya viene con un atajo listo:

| Botón del mouse | Qué hace en Albion |
|---|---|
| Botón lateral de **abajo** | `SHIFT+N` → abre el **mapa de viajero** |

---

## 📋 Antes de empezar

Necesitas:

- Una PC con **Omarchy 4.0 o más nuevo**. Para ver tu versión, ejecuta `omarchy version` en una terminal.
- **Albion Online** instalado (Steam o el launcher normal, da igual).
- Un mouse con botones laterales (si quieres usar esos botones).

---

## 🚀 Instalación (2 minutos)

### Paso 1: Abre una terminal

Presiona **`Super + Enter`**. La tecla `Super` es la que tiene el logo de Windows.

### Paso 2: Copia y pega este comando

Copia la línea completa, pégala en la terminal con **`Ctrl + Shift + V`** y presiona **`Enter`**:

```sh
omarchy plugin add https://github.com/Fcogarciaro/Albion-Binds-Omarchy.git --enable
```

Te va a hacer dos preguntas. Se contestan con las **flechas** y **`Enter`**:

1. **"Clone and add this plugin?"**: antes sale un aviso de que los plugins corren con tus permisos.
   Elige **Yes** y presiona **`Enter`**.
2. **"Place fcogarcia.albion-binds in which bar section?"**: ya viene marcada la opción **right** (derecha).
   Solo presiona **`Enter`**.

Al final debe decir **`Enabled fcogarcia.albion-binds`**.

### Paso 3: Busca el ícono de la espada ⚔️

Arriba a la derecha de la barra debe aparecer un **ícono de espada**. Con eso ya quedó instalado.

> **¿No aparece la espada?** Ejecuta este comando y vuelve a buscarla:
>
> ```sh
> omarchy restart shell
> ```

### Paso 4: Pruébalo

1. Abre **Albion Online** y entra al juego.
2. Presiona el **botón lateral de abajo** del mouse.
3. Se debe abrir el **mapa de viajero**. ✅

---

## 🎮 Cómo usarlo

### Abrir el panel

Haz **clic izquierdo** en la espada ⚔️ de la barra. Se abre un panel así:

```
⚔  Albion Binds                      [■■]  ← interruptor general
   ACTIVO · SOLO EN ALBION
──────────────────────────────────────────
ATAJOS
Botón lateral abajo  →  SHIFT+N    [■■] 🗑
──────────────────────────────────────────
AGREGAR ATAJO
Botón: [ Botón lateral abajo        ▾ ]
[ Atajo en Albion (ej. SHIFT+N) ] [Agregar]
```

### Agregar un atajo nuevo

1. En **Botón**, elige cuál quieres usar:
   - **Botón lateral abajo**
   - **Botón lateral arriba**
   - **Clic de la rueda**
   - **Otra tecla…**: escribe la tecla, por ejemplo `F5`, o el número de botón, por ejemplo `mouse:277`.
2. En el cuadro de texto, escribe el atajo que quieres que se presione **en Albion**:
   - `SHIFT+N`: mapa de viajero
   - `M`: mapa normal
   - `CTRL+1`
   - `ALT+SHIFT+M`
3. Presiona **Agregar** (o `Enter`).

Modificadores que puedes usar: `SHIFT`, `CTRL`, `ALT` y `SUPER`. Se unen con `+`.

### Pausar, activar o quitar atajos

- **Interruptor junto a cada atajo**: lo activa o lo pausa sin borrarlo.
- **Bote de basura 🗑**: borra el atajo.
- **Interruptor de arriba**: pausa o activa **todos** los atajos de una vez.
- **Clic derecho en la espada**: hace lo mismo que el interruptor de arriba, sin abrir el panel.

Si la espada se ve **opaca**, no hay ningún atajo funcionando: o están en pausa, o todos están apagados.

Los cambios se aplican al instante. No tienes que reiniciar nada.

---

## 🔄 Actualizar el plugin

Cuando haya una versión nueva, abre una terminal y ejecuta:

```sh
omarchy plugin update fcogarcia.albion-binds
```

Si hay cambios, te los muestra y te pregunta si quieres aplicarlos: elige **Yes** y presiona **`Enter`**.

---

## 🗑️ Desinstalar

En una terminal, ejecuta estos comandos uno por uno.
El primero te pide confirmar: elige **Yes** y presiona **`Enter`**.

```sh
omarchy plugin remove fcogarcia.albion-binds
rm ~/.config/hypr/albion-binds.lua
sed -i '/albion-binds/d' ~/.config/hypr/hyprland.lua
hyprctl reload
```

---

## 🛠️ Si algo no funciona

**El botón no hace nada en Albion**

- Revisa que la espada no esté opaca y que el atajo tenga su interruptor encendido.
- Haz clic dentro de la ventana del juego para que tenga el foco y vuelve a probar.
- Tu mouse puede tener los botones laterales al revés: agrega el mismo atajo con
  **Botón lateral arriba** y prueba ese.

**Abre el mapa normal en vez del mapa de viajero**

Revisa que el atajo diga `SHIFT+N` y no solo `N`.

**Quiero ver si Hyprland tiene algún error**

```sh
hyprctl configerrors
```

Si no sale nada, todo está bien.

---

## ⚙️ Cómo funciona (para curiosos)

- Los atajos se guardan en `~/.config/omarchy/shell.json`.
- El plugin genera el archivo `~/.config/hypr/albion-binds.lua` y agrega esta línea al final de
  `~/.config/hypr/hyprland.lua` para que Hyprland lo cargue siempre, aunque la barra no esté abierta:

  ```lua
  pcall(require, "hypr.albion-binds")
  ```

- Los atajos solo se registran mientras la ventana activa es Albion (clase `Albion-Online`, ya sea la
  actual o la original de la ventana, por ejemplo si el juego se abre desde Steam). Al cambiar a otra ventana se quitan,
  y los botones vuelven a su función normal.
- Al quitarlos, el plugin solo retira **sus propios** atajos. Si tú ya tenías otro atajo en el mismo botón,
  no se toca ni se interfiere con él.
- Albion corre en XWayland y no detecta un `SHIFT` "virtual". Por eso el plugin presiona la tecla
  `Shift` real, luego la tecla, y suelta todo en orden inverso, con 40 ms entre cada paso.
- Si cambias de ventana a mitad de un atajo, el plugin suelta de inmediato las teclas que haya
  dejado presionadas, para que ningún `Shift` o `Ctrl` se quede pegado. Si vuelves a presionar el botón
  mientras un atajo sigue en curso, se ignora.
- Antes de guardar el archivo, se valida con `luac -p` (si lo tienes instalado). Si el archivo generado
  tuviera un error, no se aplica y verás el mensaje en el panel.

> **Importante:** desactivar o quitar el plugin **no** borra los atajos de Hyprland, porque viven en
> `~/.config/hypr/albion-binds.lua`. Antes de quitarlo, apaga el **interruptor general** del panel,
> o sigue los pasos de la sección **Desinstalar** para limpiar todo.

## 🧪 Desarrollo

Las pruebas necesitan `node` y `lua` (con `luac`):

```sh
npm test
# equivale a: node --test "tests/**/*.test.mjs"
```

En versiones recientes de Node, `node --test tests/` no acepta un directorio, por eso se usa el patrón de arriba.

## Licencia

MIT
