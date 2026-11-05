/// Traducción de nombres de lugares de Pokémon al español de España.
/// Los nombres propios oficiales más habituales se traducen explícitamente;
/// los nombres compuestos usan reglas para no dejar etiquetas como "Route" o "City".
String locationNameEs(String source) {
  final key = source.trim();
  const exact = <String, String>{
    'Pallet Town': 'Pueblo Paleta', 'Viridian City': 'Ciudad Verde',
    'Pewter City': 'Ciudad Plateada', 'Cerulean City': 'Ciudad Celeste',
    'Vermilion City': 'Ciudad Carmín', 'Lavender Town': 'Pueblo Lavanda',
    'Celadon City': 'Ciudad Azulona', 'Fuchsia City': 'Ciudad Fucsia',
    'Saffron City': 'Ciudad Azafrán', 'Cinnabar Island': 'Isla Canela',
    'Indigo Plateau': 'Meseta Añil', 'Viridian Forest': 'Bosque Verde',
    'Mt Moon': 'Monte Moon', 'Rock Tunnel': 'Túnel Roca',
    'Seafoam Islands': 'Islas Espuma', 'Cerulean Cave': 'Cueva Celeste',
    'Power Plant': 'Central Energía', 'Pokemon Mansion': 'Mansión Pokémon',
    'Victory Road': 'Calle Victoria', 'New Bark Town': 'Pueblo Primavera',
    'Cherrygrove City': 'Ciudad Cerezo', 'Violet City': 'Ciudad Malva',
    'Azalea Town': 'Pueblo Azalea', 'Goldenrod City': 'Ciudad Trigal',
    'Ecruteak City': 'Ciudad Iris', 'Olivine City': 'Ciudad Olivo',
    'Cianwood City': 'Ciudad Orquídea', 'Mahogany Town': 'Pueblo Caoba',
    'Blackthorn City': 'Ciudad Endrino', 'Lake Of Rage': 'Lago de la Furia',
    'Ilex Forest': 'Encinar', 'National Park': 'Parque Nacional',
    'Burned Tower': 'Torre Quemada', 'Bell Tower': 'Torre Campana',
    'Ruins Of Alph': 'Ruinas Alfa',
    'Littleroot Town': 'Villa Raíz', 'Oldale Town': 'Pueblo Verdegal',
    'Petalburg City': 'Ciudad Petalia', 'Rustboro City': 'Ciudad Férrica',
    'Dewford Town': 'Pueblo Azuliza', 'Slateport City': 'Ciudad Portual',
    'Mauville City': 'Ciudad Malvalona', 'Verdanturf Town': 'Pueblo Verdegal',
    'Fallarbor Town': 'Pueblo Pardal', 'Lavaridge Town': 'Pueblo Lavacalda',
    'Fortree City': 'Ciudad Arborada', 'Lilycove City': 'Ciudad Calagua',
    'Mossdeep City': 'Ciudad Algaria', 'Sootopolis City': 'Arrecípolis',
    'Ever Grande City': 'Ciudad Colosalia', 'Sky Pillar': 'Pilar Celeste',
    'Meteor Falls': 'Cascada Meteoro', 'Granite Cave': 'Cueva Granito',
    'Petalburg Woods': 'Bosque Petalia', 'New Mauville': 'Malvalanova',
    'Rusturf Tunnel': 'Túnel Fervergal', 'Nuvema Town': 'Pueblo Arcilla',
    'Accumula Town': 'Pueblo Terracota', 'Striaton City': 'Ciudad Gres',
    'Nacrene City': 'Ciudad Esmalte', 'Castelia City': 'Ciudad Porcelana',
    'Nimbasa City': 'Ciudad Mayólica', 'Driftveil City': 'Ciudad Fayenza',
    'Mistralton City': 'Ciudad Loza', 'Icirrus City': 'Ciudad Teja',
    'Opelucid City': 'Ciudad Caolín', 'Lacunosa Town': 'Pueblo Ladrillo',
    'Undella Town': 'Pueblo Arenisca', 'Black City': 'Ciudad Negra',
    'White Forest': 'Bosque Blanco', 'Dragonspiral Tower': 'Torre Dragón',
    'Pinwheel Forest': 'Bosque Azulejo', 'Chargestone Cave': 'Cueva Electrorroca',
    'Relic Castle': 'Castillo Ancestral', 'Anville Town': 'Pueblo Biscuit',
    'Aspertia City': 'Ciudad Engobe', 'Floccesy Town': 'Pueblo Ocre',
    'Virbank City': 'Ciudad Hormigón', 'Humilau City': 'Ciudad Marga',
    'Lentimas Town': 'Pueblo Chamota', 'Dendemille Town': 'Pueblo Fresco',
    'Vaniville Town': 'Pueblo Boceto', 'Aquacorde Town': 'Pueblo Acuarela',
    'Lumiose City': 'Ciudad Luminalia', 'Santalune City': 'Ciudad Novarte',
    'Camphrier Town': 'Pueblo Acuarela', 'Cyllage City': 'Ciudad Relieve',
    'Shalour City': 'Ciudad Yantra', 'Coumarine City': 'Ciudad Témpera',
    'Laverre City': 'Ciudad Romantis', 'Anistar City': 'Ciudad Fluxus',
    'Snowbelle City': 'Ciudad Fractal', 'Kiloude City': 'Ciudad Batik',
    'Postwick': 'Pueblo Yarda', 'Wedgehurst': 'Pueblo Par',
    'Motostoke': 'Pueblo Amura', 'Hulbury': 'Pueblo Artejo',
    'Hammerlocke': 'Ciudad Artejo', 'Stow On Side': 'Pueblo Ladera',
    'Ballonlea': 'Pueblo Plié', 'Circhester': 'Ciudad Puntera',
    'Spikemuth': 'Pueblo Crampón', 'Wyndon': 'Ciudad Puntera',
    'Slumbering Weald': 'Bosque Onírico', 'Lake Of Outrage': 'Lago del Enfado',
    'Dusty Bowl': 'Cuenca Polvorienta', 'Bridge Field': 'Llanura Puente',
    'Rolling Fields': 'Pradera Rodante', 'Watchtower Ruins': 'Ruinas de la Atalaya',
    'Giants Seat': 'Asiento del Gigante', 'Giants Cap': 'Gorro del Gigante',
    'Giants Mirror': 'Espejo del Gigante', 'Stony Wilderness': 'Páramo Pedregoso',
    'Motostoke Riverbank': 'Ribera de Amura', 'Lake Verity': 'Lago Veraz',
    'Lake Valor': 'Lago Valor', 'Lake Acuity': 'Lago Agudeza',
    'Twinleaf Town': 'Pueblo Hojaverde', 'Sandgem Town': 'Pueblo Arena',
    'Jubilife City': 'Ciudad Jubileo', 'Oreburgh City': 'Ciudad Pirita',
    'Floaroma Town': 'Pueblo Aromaflor', 'Eterna City': 'Ciudad Vetusta',
    'Hearthome City': 'Ciudad Corazón', 'Solaceon Town': 'Pueblo Sosiego',
    'Veilstone City': 'Ciudad Rocavelo', 'Pastoria City': 'Ciudad Pradera',
    'Celestic Town': 'Pueblo Caelestis', 'Canalave City': 'Ciudad Canal',
    'Snowpoint City': 'Ciudad Puntaneva', 'Sunyshore City': 'Ciudad Marina',
    'Fight Area': 'Zona de Combate', 'Survival Area': 'Zona Sobrevivir',
    'Resort Area': 'Zona Descanso', 'Mt Coronet': 'Monte Corona',
    'Spear Pillar': 'Columna Lanza', 'Distortion World': 'Mundo Distorsión',
    'Flower Paradise': 'Paraíso Floral', 'Stark Mountain': 'Monte Dura',
    'Alola Route 1': 'Ruta 1 de Alola', 'Alola Route 2': 'Ruta 2 de Alola',
  };
  if (exact.containsKey(key)) return exact[key]!;

  var s = key;
  // Regiones y numeración de rutas.
  s = s.replaceAll(RegExp(r'^Kanto Route '), 'Ruta ')
       .replaceAll(RegExp(r'^Johto Route '), 'Ruta ')
       .replaceAll(RegExp(r'^Hoenn Route '), 'Ruta ')
       .replaceAll(RegExp(r'^Sinnoh Route '), 'Ruta ')
       .replaceAll(RegExp(r'^Unova Route '), 'Ruta ')
       .replaceAll(RegExp(r'^Kalos Route '), 'Ruta ')
       .replaceAll(RegExp(r'^Galar Route '), 'Ruta ')
       .replaceAll(RegExp(r'^Alola Route '), 'Ruta ');
  s = s.replaceAll(' City', '').replaceAll(' Town', '')
       .replaceAll(' Route ', ' Ruta ')
       .replaceAll(' Forest', ' (bosque)')
       .replaceAll(' Cave', ' (cueva)')
       .replaceAll(' Mountain', ' (montaña)')
       .replaceAll(' Island', ' (isla)')
       .replaceAll(' Lake', ' (lago)')
       .replaceAll(' Sea', ' (mar)')
       .replaceAll(' Beach', ' (playa)')
       .replaceAll(' Meadow', ' (prado)')
       .replaceAll(' Woods', ' (bosque)')
       .replaceAll(' Safari Zone', ' Zona Safari')
       .replaceAll(' Victory Road', ' Calle Victoria')
       .replaceAll(' Department Store', ' Centro Comercial')
       .replaceAll(' Pokemon Center', ' Centro Pokémon')
       .replaceAll(' Pokemon Mart', ' Tienda Pokémon')
       .replaceAll(' Poke Mart', ' Tienda Pokémon')
       .replaceAll(' Gym', ' Gimnasio')
       .replaceAll(' Outside', ' (exterior)')
       .replaceAll(' Inside', ' (interior)')
       .replaceAll(' Entrance', ' (entrada)')
       .replaceAll(' Main', ' (zona principal)')
       .replaceAll(' North', ' norte')
       .replaceAll(' South', ' sur')
       .replaceAll(' East', ' este')
       .replaceAll(' West', ' oeste');
  s = s.replaceAll(RegExp(r'\bMt '), 'Monte ')
       .replaceAll(RegExp(r'\bB(\d+)f\b', caseSensitive: false), r'planta sótano $1')
       .replaceAll(RegExp(r'\b(\d+)f\b', caseSensitive: false), r'planta $1');
  return s;
}
