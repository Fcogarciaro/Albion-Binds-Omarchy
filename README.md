# ⚔️ Albion Companion

Plugin para la barra de **Omarchy** con herramientas para Albion Online. Hoy incluye **Atajos** y **Cultivos**. Atajos te deja asignar atajos a los botones del mouse
(o a cualquier tecla) que **solo funcionan dentro de Albion Online**.

Cuando no estás en el juego, los botones siguen haciendo lo de siempre
(por ejemplo, el botón lateral sigue siendo "Atrás" en el navegador).

El panel tiene tres pestañas (y Cultivos y Zona negra también se abren en una [ventana grande](#-ventana-grande)):

- **Atajos**: lo que describe este documento.
- **Cultivos**: bitácora de ganancias de tu isla (ver [Cultivos](#-cultivos)).
- **Zona negra**: cuánta plata pierdes en muertes frente a cuánta ganas en cofres (ver la sección Zona negra más abajo).

El panel (y la ventana grande) **se abre en la última pestaña que usaste**. Esa elección se guarda en `data.json` (`ui.tab`); en la ventana grande, que no tiene Atajos, se abre en Cultivos si tu última pestaña fue Atajos.

> ¿Vienes de **Albion Binds**? Ve a [Migrar desde Albion Binds](#-migrar-desde-albion-binds).

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
omarchy plugin add https://github.com/Fcogarciaro/Albion-Companion-Omarchy.git --enable
```

Te va a hacer dos preguntas. Se contestan con las **flechas** y **`Enter`**:

1. **"Clone and add this plugin?"**: antes sale un aviso de que los plugins corren con tus permisos.
   Elige **Yes** y presiona **`Enter`**.
2. **"Place fcogarcia.albion-companion in which bar section?"**: ya viene marcada la opción **right** (derecha).
   Solo presiona **`Enter`**.

Al final debe decir **`Enabled fcogarcia.albion-companion`**.

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

Haz **clic izquierdo** en la espada ⚔️ de la barra. Se abre un panel con pestañas; **Atajos** se ve así:

```
[ Atajos ] [ Cultivos ] [ Zona negra ]   ← pestañas
──────────────────────────────────────────
⚔  Albion Companion                  [■■]  ← interruptor general
   ACTIVO · SOLO EN ALBION
──────────────────────────────────────────
ATAJOS
Botón lateral abajo  →  SHIFT+N    [■■] 🗑
──────────────────────────────────────────
AGREGAR ATAJO
Botón: [ Botón lateral abajo        ▾ ]
[ Atajo en Albion (ej. SHIFT+N) ] [Agregar]
──────────────────────────────────────────
RESPALDO
~/albion-companion.json
[Exportar] [Importar]
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

### 🔁 Llevar tus atajos a otra PC

1. En la PC donde ya tienes tus atajos, abre el panel y presiona **Exportar**.
   Se crea el archivo `~/albion-companion.json` en tu carpeta personal.
2. Copia ese archivo a la carpeta personal de la otra PC (USB, Drive, Syncthing…).
3. En la otra PC, abre el panel y presiona **Importar**.

> **Ojo:** importar **reemplaza** tus atajos actuales (y el interruptor general) por los del archivo.
> Si el archivo tiene atajos inválidos, se ignoran y el panel te dice cuántos.

---

## 🌾 Cultivos

La pestaña **Cultivos** está pensada para anotar rápido y verse poco: arriba el **resumen** (ganancia total y cuántas parcelas están creciendo o listas), debajo **una tarjeta por parcela**, luego los **últimos ciclos**, y al final, plegado, lo que casi no usas (agregar parcela, planificador e impuesto).

Lleva la cuenta de lo que realmente ganas con tu isla. Albion no ofrece ninguna forma de leer el estado de la isla,
así que **tú anotas cada ciclo** y el plugin calcula la ganancia.
Cubre los cultivos de **T1 a T8** (zanahorias, frijoles, manojo de trigo, rábanos, coles, patatas, fardo de maíz y calabaza, con los nombres del juego en español). Hierbas y animales no están incluidos.

### Cómo anotar un ciclo

1. Abre **Agregar parcela ›** (al final de la pestaña), escribe el nombre y presiona **Agregar** (una vez por parcela).
2. Cada parcela es una tarjeta con su **estado** y **un solo botón**:
   - **Vacía** → botón **Plantar**.
   - **Creciendo** (ya plantada) → botón **Cosechar**.
   - **Lista para cosechar** (pasaron 22 horas desde que plantaste; el color de acento te avisa) → botón **Cosechar**.
3. El botón abre **una tarjeta de captura** justo debajo de las parcelas (solo una a la vez; la parcela abierta queda resaltada). El cursor ya está en el primer campo:
   - **Plantar**: elige el cultivo, cuántas semillas plantaste y a qué precio.
   - **Cosechar**: cuántos cultivos salieron, cuántas semillas te devolvieron y a qué precio vendes cada cultivo.
4. **Enter** pasa al siguiente campo y guarda en el último (o presiona **Guardar siembra** / **Guardar cosecha**). Al guardar, la tarjeta se cierra y ves un breve **✓ Guardado** junto al resumen. La **✕** cierra la tarjeta sin guardar.
5. El ciclo pasa a **Últimos ciclos** (los 3 más recientes; **Ver todo ›** muestra más) y la parcela muestra su total.

El estado «Creciendo / Lista» es una **estimación**: Albion no deja leer la isla, así que el plugin cuenta 22 horas desde la hora a la que anotaste la siembra.

Cada parcela puede tener **un solo ciclo abierto** a la vez. Si se perdió la cosecha, anota 0 cultivos.

Si te equivocas, puedes borrar: el botón **⋯** de cada parcela abre **Cancelar siembra** (ciclo abierto) y **Eliminar parcela** (borra también sus ciclos); **Eliminar** va en cada fila de los últimos ciclos. Pide confirmación: el primer toque cambia el botón a **¿Seguro?** y el segundo borra.

### Escribir cantidades de plata rápido

En todos los campos de plata (precio de semilla o cultivo, valor perdido, botín y gasto) puedes usar abreviaturas:

| Escribes | Se guarda |
| --- | --- |
| `450k` | 450,000 |
| `1.2m` o `1,2m` | 1,200,000 |
| `12,5k` | 12,500 |
| `1.500.000` o `1,500,000` | 1,500,000 |

`k` es mil y `m` es millón (mayúsculas o minúsculas). Un punto o coma seguido de exactamente tres dígitos son miles (`1.500` = 1,500). Un decimal solo se acepta con `k` o `m`: `1.5` sin letra es ambiguo y se rechaza con un aviso. Cantidades, semillas y tomos siguen siendo números enteros.

### Cómo se calcula la ganancia

```
cultivos × precio × (1 − impuesto)  +  (semillas devueltas − semillas plantadas) × precio de la semilla
```

- Las semillas se valoran al precio que anotaste al plantar.
- El **impuesto** por defecto es **6.5 %** (4 % con premium + 2.5 % de la orden de venta). Puedes cambiarlo en **Impuesto de venta ›**, al final de la pestaña.
- Las cifras se redondean a plata entera y solo cuentan los ciclos ya cosechados.

### Precio de mercado (opcional)

En la tarjeta de captura, el botón **Precio de mercado** rellena el precio con el más bajo en venta de la ciudad que elijas, usando los datos del
[Albion Online Data Project](https://www.albion-online-data.com/) (servidor América).

- Esos datos los suben **otros jugadores**, así que pueden estar **desactualizados o faltar** (por ejemplo, las semillas de frijol casi nunca tienen precio).
- Si no hay datos o no hay internet, el campo se queda vacío y puedes escribir el precio a mano. Nada se bloquea.
- Usa `curl`, que ya viene con Omarchy.

### Planificador de rotación

La sección **Planificador ›** (plegada al final de la pestaña; tócala para abrirla) te ayuda a decidir qué plantar después. Con la ciudad que elijas, consulta de una sola vez los precios de todos los cultivos y semillas y ordena los cultivos de mayor a menor **ganancia esperada por parcela y ciclo**:

```
semillas × cultivos por semilla × precio × (1 − impuesto)  +  (semillas devueltas − semillas por parcela) × precio de la semilla
```

- Cada fila dice de dónde sale el rendimiento: **historial** si ya cerraste al menos un ciclo de ese cultivo (se usa el promedio real de tus cosechas), o **estimado** si no (se usan los datos del juego).
- Si falta el precio del cultivo, la fila dice **sin precio** y va al final. Si solo falta el de la semilla, la ganancia cuenta solo la venta de cultivos y se marca como **parcial**, y va después de las filas completas.
- Ajustes (se guardan en `data.json`): **Premium** (duplica los cultivos por semilla), **Riego con foco** (más semillas devueltas) y **Semillas por parcela** (9 por defecto; cámbialo si en tu juego es otro número).
- Los valores estimados salen de los datos del juego y son **aproximados**; el efecto de Premium en los cultivos viene de la wiki y no está en los datos oficiales. Tu historial los reemplaza en cuanto lo tengas.
- Los precios, como arriba, los suben otros jugadores y pueden estar desactualizados. Si no hay internet, solo verás un aviso.

### Dónde se guardan los datos

En `~/.local/share/albion-companion/data.json`. Se guarda solo, cada vez que haces un cambio.
Para tener el mismo historial en varias PCs, sigue [Sincronizar tus datos entre PCs](#-sincronizar-tus-datos-entre-pcs-nextcloud).

---

## ⚔️ Zona negra

La pestaña **Zona negra** te dice si tus salidas a zona negra **valen la pena**: compara la plata que pierdes cuando mueres (el valor de tu set) con la que ganas en cofres. Albion no ofrece ninguna forma de leer tus muertes ni tu botín,
así que **tú anotas ambas cosas** y el plugin hace la cuenta.

### Cómo está organizada

De arriba abajo:

1. **Resumen**: el balance (en rojo si es negativo) y tres cifras, **Ganado**, **Perdido** y **Gastado**, cada una con su cuenta.
2. **Tres botones de captura**: **+ Botín**, **+ Gasto** y **✝ Muerte**. Si ya hay un gasto, debajo aparece **↻ Repetir: nota −valor**.
3. **Una tarjeta de captura** (solo una a la vez) que se abre al tocar un botón. Tiene una **✕** para cerrarla, el cursor ya está en su primer campo y **Enter guarda**. Al guardar, la tarjeta se cierra y ves un breve **✓ Guardado** junto al balance.
4. **Últimos movimientos**: siempre ves los 3 más recientes. **Ver todo ›** abre la lista más larga (sin abrirse sola nunca).
5. **Mis sets (n) ›**, plegado al final. Ahí está el editor de sets.

### Crear un set

1. Abre **Mis sets (n) ›** (al final de la pestaña), escribe un nombre (por ejemplo "Tanque T8") y presiona **Crear**.
2. Presiona **Editar** en ese set. Para cada pieza elige la **ranura** (cabeza, pecho, zapatos, arma principal, arma secundaria, capa, bolsa, montura, poción o comida), busca la pieza por nombre en la lista, y elige **nivel** (tier), **encantamiento** (.0 a .4) y **calidad** (de Normal a Obra maestra). Presiona **Agregar pieza**.
3. En **poción** y **comida** no hay calidad, pero sí **cantidad** (cuántas llevas). Déjala vacía si es una sola.
4. **Quitar** borra una pieza; **Renombrar** cambia el nombre del set.

La lista de piezas sale de los datos del juego (`ao-bin-dumps`) y viene guardada en el plugin: no necesita internet.

### Registrar una muerte

1. Presiona **✝ Muerte**. Tus sets aparecen como **botones**: toca el que llevabas. El plugin **recuerda el último** y lo deja elegido.
2. Al elegir un set, el plugin **consulta solo los precios** de todas sus piezas en la **ciudad** de referencia (puedes cambiarla y presionar **Actualizar precios**). Cada pieza muestra su precio (× la cantidad), o **sin precio** si nadie lo reportó.
3. El **total perdido** se rellena con la suma. Puedes **corregirlo a mano** (por ejemplo si faltaban precios o si no recuperaste todo); si ya lo escribiste, los precios que lleguen después no lo pisan.
4. Presiona **Enter** o **Guardar muerte**. Si no hay precios, escribe el valor tú.

Atajo: en **Mis sets**, **Morí con este set** abre la tarjeta de muerte con ese set elegido y consulta los precios al instante.

Una muerte guarda una **foto de los precios** del momento: si el mercado cambia después, tu historial no se reescribe. Si faltó algún precio, aparece como **(parcial)** en el historial.

### Registrar un botín

Presiona **+ Botín**, escribe la plata que sacaste (lo que vale lo que vendiste o lo que te dio el cofre) y, si quieres, una nota. Presiona **Enter** o **Guardar botín**.

En la misma tarjeta puedes contar los **Tomos de conocimiento** que te cayeron, por nivel (T1 a T8). Solo se cuentan: no tienen valor en plata y no entran en la ganancia. El resumen muestra el total de cada nivel y el historial los anota en cada botín; puedes guardar un botín solo con tomos y sin plata.

### Registrar un gasto

Si pagas para llegar a zona negra (por ejemplo el portal SAFE), presiona **+ Gasto**, escribe lo que costó y una nota (si la dejas vacía se guarda como «Portal»). Los gastos se restan de la ganancia y aparecen como **Gastado** en el resumen y como filas «Gasto» en los movimientos.

Si repites el mismo gasto, usa **↻ Repetir: Portal SAFE −12k** (debajo de los tres botones): un toque anota otro gasto con el mismo valor y nota, con la hora de ahora. El botón no aparece si todavía no hay ningún gasto. La tarjeta de gasto siempre empieza vacía.

### Cosas que recuerda el plugin

Para escribir menos, el plugin recuerda tu **ciudad** (la misma para Cultivos, el planificador y las muertes), el **último set** de muerte y la **última pestaña**. Se guardan en `data.json` (sección `ui`), así que viajan contigo si sincronizas entre PCs.

Además recuerda la **última pestaña** abierta. En las tarjetas de captura, **Enter guarda** (en la de plantar y cosechar de Cultivos, Enter pasa al siguiente campo y guarda en el último). Al abrir una tarjeta, el cursor ya está en su primer campo.

### Cómo se calcula la ganancia

```
ganancia = suma del botín − suma de las muertes − suma de los gastos
```

- **Ganado** es la suma de tus botines, **Perdido** la suma del valor de tus muertes, **Gastado** la suma de tus gastos, y arriba ves el balance (en rojo si es negativo). Cuando ya hay muertes, también se muestra el botín medio por muerte.
- Cada set muestra cuántas veces murió y cuánto perdió. El botín no se asigna a un set, por eso la ganancia es total.
- Los precios salen del [Albion Online Data Project](https://www.albion-online-data.com/) (servidor América): los suben **otros jugadores**, así que pueden estar **desactualizados o faltar**, sobre todo en calidades altas. Es solo una referencia: el valor final lo decides tú.

### Borrar

- **Eliminar** en una fila de **Últimos movimientos** borra esa muerte, ese botín o ese gasto y cambia los totales.
- **Eliminar set** (en **Mis sets**, dentro de Editar) borra el set, pero **las muertes que ya registraste se quedan** con el nombre que tenía el set.
- Pide confirmación: el primer toque cambia el botón a **¿Seguro?** y el segundo borra.

Los datos se guardan en el mismo `data.json` que Cultivos (ver [Dónde se guardan los datos](#dónde-se-guardan-los-datos)) y se sincronizan igual.

---

## 🪟 Ventana grande

El panel de la barra es angosto. Para anotar con más espacio hay una **ventana grande** (unos 1000×700, centrada en la pantalla) con las pestañas **Cultivos** y **Zona negra**. La **captura** (botones, tarjeta de captura y parcelas o sets) queda a la izquierda, y el **resumen** y el **historial completo** a la derecha; ahí el historial ya viene desplegado, sin «Ver todo». Se abre en la última pestaña que usaste. Es la misma información que el panel: lo que anotes en uno aparece en el otro.

### Cómo abrirla

1. Abre el panel (clic izquierdo en la espada ⚔️).
2. Entra a la pestaña **Cultivos** o **Zona negra**.
3. Presiona **Abrir ventana grande**. El panel se cierra y se abre la ventana.

Para cerrarla: tecla **`Esc`**, el botón **Cerrar**, o un clic fuera de la ventana. Con **`Tab`** cambias entre Cultivos y Zona negra. Si estás escribiendo en un campo, `Esc` primero te saca del campo y el siguiente `Esc` cierra la ventana.

> **Atajos** (los botones del mouse) se queda solo en el panel de la barra. La ventana grande no los muestra.

### Abrirla con una tecla (opcional)

Puedes asignarle una combinación de teclas en Hyprland. En Omarchy tus atajos personales van en el archivo `~/.config/hypr/bindings.lua`. Ábrelo y agrega estas líneas al final (cambia `SUPER + ALT + A` por la combinación que prefieras, una que no uses ya):

```lua
o.bind(
  "SUPER + ALT + A",
  "Albion Companion",
  "omarchy-shell shell toggle fcogarcia.albion-companion '{}'"
)
```

Guarda el archivo; Hyprland suele recargar la configuración solo (si no, ejecuta `hyprctl reload`). La misma tecla abre y cierra la ventana. Para ver todas tus combinaciones y comprobar que no se repite, ejecuta `omarchy menu keybindings --print`.

### Si tocas el panel y la ventana a la vez

Los dos leen y guardan el mismo archivo (`~/.local/share/albion-companion/data.json`) y se actualizan entre sí al instante. Si anotas algo en el panel y en la ventana **en el mismo instante** (cosa que en la práctica no pasa, porque son dos manos en dos lugares), gana lo último que se guardó. Usa uno a la vez y no pierdes nada.

### Si la ventana no se abre después de actualizar

Si actualizaste el plugin (o lo instalaste) y el botón o la tecla no abren nada, reinicia el shell de Omarchy para que registre la ventana nueva:

```sh
omarchy restart shell
```

Luego prueba otra vez.

---

## ☁️ Sincronizar tus datos entre PCs (Nextcloud)

Si juegas en más de una PC, puedes hacer que todas usen **el mismo historial de cultivos** sin anotarlo dos veces.
La idea: el archivo de datos vive dentro de tu carpeta de **Nextcloud**, y Nextcloud lo mantiene igual en todas tus PCs.

- Basta con que **una** PC esté encendida: Nextcloud sube el cambio a tu servidor y la otra PC lo baja cuando se prende.
- El plugin **detecta solo** cuando el archivo cambia y recarga los datos. No tienes que reiniciar nada.
- Esto sincroniza **solo los datos de Cultivos**. Tus atajos se siguen pasando con [Exportar e Importar](#-llevar-tus-atajos-a-otra-pc).

### Antes de empezar

Necesitas:

- El cliente de Nextcloud instalado y con tu cuenta iniciada en **cada PC**. Si no lo tienes:

  ```sh
  sudo pacman -S nextcloud-client
  ```

- Saber **dónde está tu carpeta de Nextcloud** en la PC. Casi siempre es `~/Nextcloud`.
  Para confirmarlo, abre el cliente de Nextcloud, ve a la configuración de tu cuenta y mira la ruta de la carpeta local.
  En los comandos de abajo se usa `~/Nextcloud`. **Si la tuya es otra, cámbiala en cada comando.**

### Paso 1: En la PC que tiene tus datos buenos

Hazlo en la PC donde ya anotaste tus parcelas y ciclos. Abre una terminal (**`Super + Enter`**) y ejecuta estos comandos **uno por uno**:

1. Crea la carpeta dentro de Nextcloud:

   ```sh
   mkdir -p ~/Nextcloud/albion-companion
   ```

2. Mueve tu archivo de datos a esa carpeta:

   ```sh
   mv ~/.local/share/albion-companion/data.json ~/Nextcloud/albion-companion/
   ```

3. Borra la carpeta vieja, que ahora está vacía:

   ```sh
   rmdir ~/.local/share/albion-companion
   ```

   > Si dice **"Directory not empty"**, detente. Hay otros archivos ahí. Muévelos también a `~/Nextcloud/albion-companion/` y vuelve a intentarlo.

4. Crea un **acceso directo** (symlink) en el lugar donde el plugin busca sus datos, apuntando a la carpeta de Nextcloud:

   ```sh
   ln -s ~/Nextcloud/albion-companion ~/.local/share/albion-companion
   ```

5. Reinicia la barra para que el plugin lea los datos desde la nueva ubicación:

   ```sh
   omarchy restart shell
   ```

6. Abre la pestaña **Cultivos** y confirma que tus parcelas siguen ahí.

7. Espera a que el ícono de Nextcloud indique que **terminó de sincronizar** antes de seguir con la otra PC.

### Paso 2: En cada una de las otras PCs

1. Espera a que Nextcloud baje la carpeta. Confirma que el archivo ya está:

   ```sh
   ls ~/Nextcloud/albion-companion/
   ```

   Debe aparecer `data.json`. Si no aparece, espera a que Nextcloud termine de sincronizar y vuelve a revisar.

2. Guarda como respaldo lo que tenía esta PC (por si acaso):

   ```sh
   mv ~/.local/share/albion-companion ~/.local/share/albion-companion.bak
   ```

   > Si dice **"No such file or directory"**, no pasa nada: esta PC no tenía datos. Sigue con el siguiente comando.

3. Crea el acceso directo:

   ```sh
   ln -s ~/Nextcloud/albion-companion ~/.local/share/albion-companion
   ```

4. Reinicia la barra:

   ```sh
   omarchy restart shell
   ```

5. Abre la pestaña **Cultivos**: debes ver las mismas parcelas que en la primera PC.

### Paso 3: Comprueba que funciona

1. En una PC, agrega una parcela de prueba (por ejemplo, `prueba`).
2. Espera unos segundos a que Nextcloud sincronice.
3. En la otra PC, abre la pestaña **Cultivos**. La parcela `prueba` debe aparecer **sin reiniciar nada**.
4. Bórrala con **Eliminar parcela**.

> **¿No aparece?** Ejecuta `omarchy restart shell` en esa PC. Si con eso aparece, la sincronización funciona pero la recarga automática no;
> [abre un issue](https://github.com/Fcogarciaro/Albion-Companion-Omarchy/issues) para revisarlo.

### Reglas importantes

- ⚠️ **Crea el acceso directo a la carpeta, nunca al archivo `data.json`.** El plugin guarda creando un archivo nuevo y reemplazando el anterior.
  Si el acceso directo apunta al archivo, el primer guardado lo convierte en un archivo normal y la sincronización **se rompe sin avisar**.
- ⚠️ **No hagas cambios en dos PCs al mismo tiempo.** Si las dos guardan antes de sincronizar, Nextcloud no puede mezclarlos:
  conserva uno y guarda el otro como copia en conflicto (un archivo con `conflicted copy` en el nombre dentro de `~/Nextcloud/albion-companion/`).
  Si ves uno, revisa cuál tiene los datos correctos y borra el otro.
- Si Nextcloud no está corriendo, el plugin funciona igual con la copia local. Los cambios se suben cuando Nextcloud vuelva a correr.

### Cómo comprobar que el acceso directo está bien

```sh
ls -l ~/.local/share/ | grep albion-companion
```

Debe verse algo así, con una flecha `->` apuntando a tu carpeta de Nextcloud:

```
albion-companion -> /home/tu-usuario/Nextcloud/albion-companion
```

Si no hay flecha, el acceso directo no está creado: repite el paso del `ln -s`.

### Dejar de sincronizar (deshacerlo)

En la PC donde quieras dejar de sincronizar:

```sh
rm ~/.local/share/albion-companion
mkdir -p ~/.local/share/albion-companion
cp ~/Nextcloud/albion-companion/data.json ~/.local/share/albion-companion/
omarchy restart shell
```

> El primer comando borra **solo el acceso directo**, no tus datos. Escríbelo **sin** `/` al final.
> Tus datos siguen en Nextcloud y ahora tienes una copia local independiente.

---

## 🚚 Migrar desde Albion Binds

El plugin cambió de nombre y de id (`fcogarcia.albion-binds` pasó a `fcogarcia.albion-companion`),
así que hay que reinstalarlo. Tus atajos se recuperan con Exportar e Importar:

1. En el plugin **viejo**, abre el panel y presiona **Exportar**. Se crea `~/albion-binds.json`.
2. Quita el plugin viejo:

   ```sh
   omarchy plugin remove fcogarcia.albion-binds --yes
   ```

3. Instala el nuevo:

   ```sh
   omarchy plugin add https://github.com/Fcogarciaro/Albion-Companion-Omarchy.git --enable --yes
   ```

4. Abre el panel nuevo y presiona **Importar**. Si no existe `~/albion-companion.json`,
   toma `~/albion-binds.json` automáticamente.

Los archivos viejos de Hyprland (`~/.config/hypr/albion-binds.lua` y su línea en `hyprland.lua`)
se limpian solos la primera vez que el plugin nuevo aplica los atajos. No tienes que borrar nada a mano.

---

## 🔄 Actualizar el plugin

Cuando haya una versión nueva, abre una terminal y ejecuta:

```sh
omarchy plugin update fcogarcia.albion-companion
```

Si hay cambios, te los muestra y te pregunta si quieres aplicarlos: elige **Yes** y presiona **`Enter`**.

---

## 🗑️ Desinstalar

En una terminal, ejecuta estos comandos uno por uno.
El primero te pide confirmar: elige **Yes** y presiona **`Enter`**.

```sh
omarchy plugin remove fcogarcia.albion-companion
rm ~/.config/hypr/albion-companion.lua
sed -i '/albion-companion/d' ~/.config/hypr/hyprland.lua
hyprctl reload
```

Opcional, para borrar también tus datos y tu respaldo:

```sh
rm -r ~/.local/share/albion-companion
rm ~/albion-companion.json
```

---

## 🛠️ Si algo no funciona

**El botón no hace nada en Albion**

- Revisa que la espada no esté opaca y que el atajo tenga su interruptor encendido.
- Haz clic dentro de la ventana del juego para que tenga el foco y vuelve a probar.
- Tu mouse puede tener los botones laterales al revés: agrega el mismo atajo con
  **Botón lateral arriba** y prueba ese.

**Juego con gamescope y los atajos no funcionan**

Los atajos funcionan con gamescope, por ejemplo con `gamescope ... -- albion-1920x800.sh`. Con gamescope, Hyprland no ve la ventana de Albion,
sino la de gamescope. Por eso el plugin reconoce la ventana `gamescope` cuyo título empieza con **Albion Online**.

1. Actualiza el plugin y reinicia la barra. Al arrancar, el plugin reescribe sus atajos:

   ```sh
   omarchy plugin update fcogarcia.albion-companion
   omarchy restart shell
   ```

2. Con el juego abierto, comprueba que el título sea el esperado:

   ```sh
   hyprctl clients -j | jq '.[] | select(.class=="gamescope") | .title'
   ```

   Debe decir `"Albion Online Client"`. En la pantalla del launcher el título es otro, así que ahí los atajos no se activan. Eso es normal.

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
- Los datos de **Cultivos** y los de **Zona negra** se guardan en `~/.local/share/albion-companion/data.json`.
- El plugin genera el archivo `~/.config/hypr/albion-companion.lua` y agrega esta línea al final de
  `~/.config/hypr/hyprland.lua` para que Hyprland lo cargue siempre, aunque la barra no esté abierta:

  ```lua
  pcall(require, "hypr.albion-companion")
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
> `~/.config/hypr/albion-companion.lua`. Antes de quitarlo, apaga el **interruptor general** del panel,
> o sigue los pasos de la sección **Desinstalar** para limpiar todo.

## 🧪 Desarrollo

Las pruebas necesitan `node` y `lua` (con `luac`):

```sh
npm test
# equivale a: node --test "tests/**/*.test.mjs"
```

En versiones recientes de Node, `node --test tests/` no acepta un directorio, por eso se usa el patrón de arriba.

### Regenerar el catálogo de piezas de Zona negra

`blackzone/GearCatalog.js` se genera a partir de [ao-bin-dumps](https://github.com/ao-data/ao-bin-dumps) (el archivo `formatted/items.json`, de unos 24 MB, que se baja a la carpeta temporal y nunca se guarda en el repositorio). Para actualizarlo después de un parche del juego:

```sh
npm run build:catalog
# o con un items.json local: npm run build:catalog -- ruta/a/items.json
```

Luego revisa el cambio con `git diff` y haz commit del archivo generado.

## Licencia

MIT
