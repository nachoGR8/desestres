import 'dart:math';

final List<String> lovePhrases = [
  'Estoy muy orgulloso de ti, nunca lo olvides 🤍',
  'Eres más fuerte de lo que crees, mi amor 🤍',
  'Te quiero muchísimo, y hoy más que ayer 🤍',
  'Que sepas que eres lo mejor que me ha pasado 🤍',
  'Respira tranquila, estoy contigo siempre 🤍',
  'No hay nada que no puedas superar 🤍',
  'Cada día me haces más feliz, te amo 🤍',
  'Tómate tu tiempo, lo estás haciendo increíble 🤍',
  'Eres mi persona favorita en el mundo 🤍',
  'Confío en ti ciegamente, ¡tú puedes con todo! 🤍',
  'Solo quiero que sepas que te admiro un montón 🤍',
  'Me encanta verte sonreír, así que respira y sonríe 🤍',
  'Que este ratito sea solo para ti, te lo mereces 🤍',
  'Estoy aquí para lo que necesites, siempre 🤍',
  'Ojalá esta app te recuerde lo mucho que te quiero 🤍',
  'Eres lo más bonito de mis días 🤍',
  'No tengas prisa, todo va a salir bien 🤍',
  'Que nada ni nadie te quite esa sonrisa 🤍',
];

String getRandomPhrase() {
  final random = Random();
  return lovePhrases[random.nextInt(lovePhrases.length)];
}
