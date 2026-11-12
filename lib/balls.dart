import 'package:flutter/material.dart';

/// Una Poké Ball con la que se puede capturar (sprite en assets/items).
class PokeBall {
  final String id;
  final String es;
  final String en;
  const PokeBall(this.id, this.es, this.en);

  String get asset => 'assets/items/$id.png';
}

/// Todas las balls de captura, en el orden de los juegos.
const kBalls = <PokeBall>[
  PokeBall('poke-ball', 'Poké Ball', 'Poké Ball'),
  PokeBall('great-ball', 'Super Ball', 'Great Ball'),
  PokeBall('ultra-ball', 'Ultra Ball', 'Ultra Ball'),
  PokeBall('master-ball', 'Master Ball', 'Master Ball'),
  PokeBall('premier-ball', 'Honor Ball', 'Premier Ball'),
  PokeBall('safari-ball', 'Safari Ball', 'Safari Ball'),
  PokeBall('sport-ball', 'Competi Ball', 'Sport Ball'),
  PokeBall('park-ball', 'Parque Ball', 'Park Ball'),
  PokeBall('fast-ball', 'Veloz Ball', 'Fast Ball'),
  PokeBall('level-ball', 'Nivel Ball', 'Level Ball'),
  PokeBall('lure-ball', 'Cebo Ball', 'Lure Ball'),
  PokeBall('heavy-ball', 'Peso Ball', 'Heavy Ball'),
  PokeBall('love-ball', 'Amor Ball', 'Love Ball'),
  PokeBall('friend-ball', 'Amigo Ball', 'Friend Ball'),
  PokeBall('moon-ball', 'Luna Ball', 'Moon Ball'),
  PokeBall('net-ball', 'Malla Ball', 'Net Ball'),
  PokeBall('dive-ball', 'Buceo Ball', 'Dive Ball'),
  PokeBall('nest-ball', 'Nido Ball', 'Nest Ball'),
  PokeBall('repeat-ball', 'Acopio Ball', 'Repeat Ball'),
  PokeBall('timer-ball', 'Turno Ball', 'Timer Ball'),
  PokeBall('luxury-ball', 'Lujo Ball', 'Luxury Ball'),
  PokeBall('dusk-ball', 'Ocaso Ball', 'Dusk Ball'),
  PokeBall('heal-ball', 'Sanar Ball', 'Heal Ball'),
  PokeBall('quick-ball', 'Rapid Ball', 'Quick Ball'),
  PokeBall('cherish-ball', 'Gloria Ball', 'Cherish Ball'),
  PokeBall('dream-ball', 'Ensueño Ball', 'Dream Ball'),
  PokeBall('beast-ball', 'Ente Ball', 'Beast Ball'),
  PokeBall('strange-ball', 'Extraña Ball', 'Strange Ball'),
  PokeBall('academy-ball', 'Academia Ball', 'Academy Ball'),
];

PokeBall? ballById(String? id) {
  if (id == null) return null;
  for (final b in kBalls) {
    if (b.id == id) return b;
  }
  return null;
}

/// Icono de una ball.
class BallIcon extends StatelessWidget {
  final String id;
  final double size;
  const BallIcon(this.id, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final b = ballById(id);
    if (b == null) return Icon(Icons.circle_outlined, size: size);
    return Image.asset(
      b.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => Icon(Icons.circle_outlined, size: size),
    );
  }
}

/// Desplegable con todas las balls (icono y nombre). `null` = sin indicar.
class BallDropdown extends StatelessWidget {
  final String? value;
  final bool spanish;
  final ValueChanged<String?> onChanged;
  const BallDropdown({
    super.key,
    required this.value,
    required this.spanish,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        value: value ?? '',
        isExpanded: true,
        menuMaxHeight: 420,
        decoration: const InputDecoration(
          labelText: 'Ball de captura',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Sin indicar')),
          for (final b in kBalls)
            DropdownMenuItem(
              value: b.id,
              child: Row(children: [
                BallIcon(b.id, size: 26),
                const SizedBox(width: 10),
                Flexible(
                    child: Text(spanish ? b.es : b.en,
                        overflow: TextOverflow.ellipsis)),
              ]),
            ),
        ],
        onChanged: (v) => onChanged(v == null || v.isEmpty ? null : v),
      );
}
