# PokeTracker


## Renderizados 3D de Pokémon HOME

En Ajustes puedes activar **Renderizados 3D (Pokémon HOME)**. La app intenta
cargar primero las imágenes locales de `assets/sprites3d/`; si aún no están
descargadas, las obtiene desde el repositorio público PokeAPI Sprites y, si
una forma no está disponible, vuelve al sprite 2D original.

Para preparar las imágenes y poder usarlas sin conexión, ejecuta desde la raíz:

```bash
python tools/download_home_sprites.py
flutter pub get
```

Los archivos originales de `assets/sprites/` no se modifican. Los renderizados
3D se atribuyen al proyecto PokeAPI Sprites; consulta su licencia y condiciones
de uso antes de redistribuir el contenido.

## Paneles, ficha y edición de datos

- El botón ☰ muestra u oculta el panel izquierdo de Pokédex/juegos.
- Al seleccionar un Pokémon se abre el panel de detalle derecho; `Esc` lo cierra.
- Un doble clic en un Pokémon abre la ficha a pantalla completa. También se cierra con `Esc` o con la X.
- En Ajustes puedes cambiar el ancho preferido de ambos laterales. La app limita esos anchos automáticamente para conservar espacio para el tracker.
- En la ficha, **Editar datos** permite corregir categoría, descripción, altura, peso, experiencia base, ratio de captura, grupos huevo, crecimiento, pasos de huevo, amistad base y estadísticas base. Las correcciones se guardan localmente y sobreviven al reinicio; restablecer las opciones visuales no las borra.
- Al pasar el ratón por una habilidad aparece su efecto. Los efectos se guardan en `assets/data/details.json` y se regeneran junto con el resto de la ficha mediante `python tools/build_details.py`.
