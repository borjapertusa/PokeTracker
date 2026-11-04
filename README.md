# Pokédex Tracker (Flutter, Windows)

## Preparar datos
1. `python tools\build_dataset.py`      (añade datos de forma; usa la caché, es rápido si ya lo ejecutaste)
2. `python tools\download_sprites.py`   (no vuelve a descargar lo que ya tienes)
3. `python tools\build_games.py`        (genera `assets\data\games.json`: una Pokédex por juego)
4. `python tools\build_details.py`      (genera `assets\data\details.json`: estadísticas, evoluciones y ubicaciones; la primera vez tarda unos minutos)

`build_games.py` imprime una tabla con las especies y entradas de cada juego y avisa de los que
queden "SIN DATOS". Ajustes: `tools\games_config.json` (qué cuenta en cada juego),
`tools\dex_lists\` (listas manuales) y `tools\dex_overrides.json` (excluir/incluir formas concretas).
Detalles en `tools\dex_lists\LEEME.txt`.

## Ejecutar y compilar
- `flutter pub get`   (hay una dependencia nueva: `url_launcher`)
- `flutter run -d windows`
- `flutter build windows --release` → `build\windows\x64\runner\Release\` (copiar la carpeta entera)

## Pokédex por juego
- Cada juego (y cada DLC) tiene su Pokédex y su progreso independientes: Rojo/Azul … Leyendas Z-A, más Pokémon HOME (todo).
- Lista de juegos agrupada por generación, con su progreso. En ventanas estrechas se abre con el botón ☰.
- Los números son los de la Pokédex regional del juego (HOME usa la nacional).
- Sin variocolor en Rojo/Azul/Amarillo; sin diferencias de género antes de la 4.ª generación.
- Tu progreso anterior pasa a Pokémon HOME.

## Trackers propios y gestión de Pokédex (barra lateral)
- **Nuevo tracker** (botón sobre la lista de juegos): crea el tracker de un juego nuevo con una o varias Pokédex.
  Eliges nombre, si tiene variocolor, diferencias de género y formas alternativas, y para cada Pokédex su contenido:
  nacional (todos), los Pokémon de una generación, o una copia de la lista de otro juego (con progreso independiente).
  Aparecen en la sección **MIS JUEGOS**.
- **Ordenar** (botón ⇅): por generación, nombre (A–Z), mayor progreso o manual (entonces el menú ⋮ de cada Pokédex
  añade *Subir* / *Bajar*).
- **Menú ⋮ de cada Pokédex**: *Renombrar* (en las de la app hay "Restaurar original"), *Eliminar* (las propias se borran con su
  progreso, cajas y datos de entrenador; las de la app solo se quitan de la lista y se recuperan con ⇅ → *Restaurar quitadas*).
  Pokémon HOME no se puede quitar.
- Todo se guarda en el equipo (`games_v1`), en `lib/game_store.dart`.

## Interfaz y opciones
- Ventana ancha: juegos | lista o cuadrícula | detalle. Atajos: **Ctrl+F** buscar · **Ctrl+,** opciones · **Esc** cerrar detalle.
- Opciones (⚙): tema, color, vista, tamaño de texto y sprites, sprites pixelados, idioma de nombres, copiar/importar progreso.

## Ficha del Pokémon
Al pulsar un Pokémon, bajo los marcadores aparece su ficha: tipos, datos (altura, peso, captura, género, huevos...),
habilidades, estadísticas base, línea evolutiva con sus requisitos y ubicaciones por juego.
Si la especie tiene varias formas (Mega, regionales...) puedes cambiar de forma con los chips de arriba de la ficha.
PokéAPI solo tiene ubicaciones de los juegos más antiguos; para el resto se muestran enlaces a PokémonDB y Serebii.
`build_details.py` imprime al final la cobertura de ubicaciones por juego.

## Cajas
Cada Pokédex tiene un botón **Cajas**: cajas de 5 filas × 6 columnas para ordenar Pokémon de ese juego.
- Pulsa un hueco para elegir un Pokémon (con buscador, formas y opción de variocolor; interruptor "Todos los Pokémon").
- Arrastra un Pokémon a otro hueco para intercambiarlos, o suéltalo sobre otra caja de la lista para moverlo allí.
- Lápiz = cambiar el nombre de la caja. Menú ⋮ = vaciar, mover o eliminar la caja. "Añadir caja" crea más.
- Varita (arriba a la derecha) = rellenar las cajas con la Pokédex del juego en orden, para reordenarlas después.
Las cajas de cada juego son independientes y se guardan automáticamente.

## Pantalla de inicio
La app abre en un menú con las secciones (ahora solo el Pokédex Tracker). El botón 🏠 de la cabecera del tracker vuelve a él.
Desde el menú también se abren las opciones (⚙ o Ctrl+,). Para añadir una sección nueva, añade un `AppSection` a la lista
de `_sections()` en `lib/launcher.dart`.

## Perfiles
Cada perfil tiene su propio progreso del tracker (todos los juegos) y sus propias cajas por juego.
- Cambia de perfil desde el selector de la barra superior del inicio, o en la sección **Perfiles** (crear, usar, editar, eliminar).
- Al editar un perfil: nombre, Pokémon favorito como icono (con opción variocolor) y, por juego, nombre e ID de entrenador.
- En el tracker, bajo el nombre del juego se ve el perfil activo y su nombre/ID en ese juego.
- Tu progreso y tus cajas anteriores pasan al primer perfil ("Perfil 1").
- Las opciones visuales (tema, tamaños…) son comunes a todos los perfiles.
- Exportar/importar progreso (en Opciones) actúa sobre el perfil activo.
