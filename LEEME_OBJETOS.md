# Objetodex de PokeTracker

La sección **Objetos** consulta el catálogo de objetos de PokéAPI y permite elegir el grupo de ediciones. Las fichas muestran icono, categoría, efecto, descripción del juego, precio cuando está disponible, Pokémon que pueden llevarlo, usos evolutivos y otros datos.

## Preparar datos e iconos para uso sin conexión

Desde la raíz del proyecto, ejecuta una vez:

```bash
dart run tool/download_items.dart
```

El comando genera `assets/data/items.json` y descarga los iconos en `assets/items/`. Después vuelve a compilar/ejecutar la aplicación:

```bash
flutter run
```

Si no se ha generado el catálogo local, la sección intenta descargar los datos de PokéAPI al abrirse y necesita conexión a Internet.

## Nota sobre disponibilidad por edición

PokéAPI ofrece índices de objetos por generación y, para algunos objetos, textos y precios asociados a grupos de versiones. No todos los registros indican con precisión si un objeto está presente en cada edición individual. La Objetodex aprovecha los datos específicos cuando existen y muestra una advertencia cuando la fuente solo permite una clasificación aproximada por generación. Leyendas Z-A se presenta de forma provisional con el inventario de generación IX si la API aún no ofrece un grupo específico.

## Completar localización ES-ES

Para actualizar los nombres oficiales de los 1025 Pokémon y los nombres/descripciones breves localizadas de las habilidades, ejecuta desde la raíz del proyecto:

```bash
dart run tool/update_spanish_data.dart
```

El proceso consulta los datos públicos de PokéAPI y actualiza `assets/data/pokedex.json` y `assets/data/details.json`. Las claves internas se conservan en inglés para mantener la compatibilidad con los identificadores de la API. Los nombres de movimientos y objetos se solicitan en español a PokéAPI cuando se cargan. En los casos en los que la fuente no proporciona un efecto largo en español, la aplicación indica que no hay traducción disponible en lugar de mostrar el texto inglés como si fuera ES-ES.


## Pokédex del DLC de Pokémon Pokopia

Se ha añadido una Pokédex independiente llamada «Pokopia: Cuenca Coralina», con 50 entradas numeradas del 001 al 050 y seguimiento de progreso separado de la Pokédex principal de Pokopia. Frillish y Jellicent incluyen sus formas macho y hembra. Se mantiene el registro variocolor desactivado porque el juego no utiliza esa mecánica en esta Pokédex. La Parte 2 no se incluye aún, ya que está anunciada para diciembre de 2026.

## Sección MT/MO/DT

Se ha añadido una sección independiente **MT/MO/DT** al inicio de la aplicación. Permite elegir los grupos de juegos principales indicados, filtrar por tipo de máquina y buscar por número o movimiento. Cada ficha muestra el movimiento enseñado, tipo, categoría, potencia, precisión, PP y efecto cuando la fuente ofrece esos datos.

La consulta utiliza los recursos de máquinas y objetos de PokéAPI. Las correspondencias se agrupan por los grupos de versiones de la API, por lo que los números pueden repetirse entre generaciones y se conservan como registros distintos. La cobertura de juegos recientes (en particular Leyendas Pokémon: Z-A y su DLC) depende de que PokéAPI publique sus grupos y máquinas; cuando no existan registros, la sección lo indicará sin inventar datos.

## Correcciones y edición de textos
- Las formas Mega y Gigamax se muestran como ramas paralelas que salen de la especie correspondiente, en una fila desplazable horizontalmente, para no sugerir que una forma especial evoluciona en otra.
- Se pueden editar y guardar localmente los efectos y descripciones de objetos, los efectos de movimientos y los efectos mostrados en la sección MT/MO/DT. Las fichas de Pokémon ya disponían de edición de datos.
- Los textos personalizados se guardan en los ajustes locales de la aplicación y prevalecen sobre el texto de la fuente de datos.

## Descargar MT/MO/DT para uso sin conexión

Desde la carpeta raíz del proyecto, con Dart instalado, ejecuta:

```powershell
dart run tool/download_machines.dart
```

El script consulta PokéAPI y genera `assets/data/machines.json`, con las máquinas por grupo de juegos y los datos de sus movimientos (nombre, tipo, categoría, potencia, precisión, PP y efecto cuando la fuente los ofrece). La pantalla MT/MO/DT prioriza este archivo local; si todavía no existe, conserva la carga en línea como alternativa.

Después de descargarlo, vuelve a compilar la aplicación para que Flutter incluya el nuevo asset:

```powershell
flutter pub get
flutter build windows
```

La descarga necesita conexión a Internet. El uso posterior de los datos descargados no la necesita. Los grupos y movimientos que PokéAPI no tenga registrados no se pueden completar automáticamente con esta fuente.
