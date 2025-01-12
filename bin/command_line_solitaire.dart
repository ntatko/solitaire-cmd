import 'package:command_line_solitaire/command_line_solitaire.dart'
    as command_line_solitaire;

void main(List<String> arguments) {
  final game = command_line_solitaire.KlondikeSolitaire();
  game.start();
}
