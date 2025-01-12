import 'package:command_line_solitaire/command_line_solitaire.dart';
import 'package:test/test.dart';

void main() {
  group('Game initialization', () {
    test('initializes with correct tableau setup', () {
      final game = KlondikeSolitaire();
      expect(game.tableau.length, equals(7));
      for (var i = 0; i < 7; i++) {
        expect(game.tableau[i].length, equals(i + 1));
        expect(game.tableau[i].last.faceUp, isTrue);
      }
    });

    test('initializes with empty foundations', () {
      final game = KlondikeSolitaire();
      expect(game.foundations.length, equals(4));
      for (var suit in ['hearts', 'diamonds', 'clubs', 'spades']) {
        expect(game.foundations[suit]!.isEmpty, isTrue);
      }
    });

    test('initializes with 24 cards in stock', () {
      final game = KlondikeSolitaire();
      expect(game.stock.length, equals(24)); // 52 - 28 (tableau cards)
    });
  });

  group('Card movement validation', () {
    test('allows king to empty column', () {
      final game = KlondikeSolitaire();
      final kingHearts = Card('hearts', 'K', faceUp: true);
      expect(game.isValidMove(kingHearts, []), isTrue);
    });

    test('allows black on red card placement', () {
      final game = KlondikeSolitaire();
      final eightClubs = Card('clubs', '8', faceUp: true);
      final nineHearts = Card('hearts', '9', faceUp: true);
      expect(game.isValidMove(eightClubs, [nineHearts]), isTrue);
    });

    test('allows red on black card placement', () {
      final game = KlondikeSolitaire();
      final sevenHearts = Card('hearts', '7', faceUp: true);
      final eightSpades = Card('spades', '8', faceUp: true);
      expect(game.isValidMove(sevenHearts, [eightSpades]), isTrue);
    });
  });

  group('Foundation moves', () {
    test('allows ace as first card', () {
      final game = KlondikeSolitaire();
      final aceHearts = Card('hearts', 'A', faceUp: true);
      expect(game.isValidFoundationMove(aceHearts, []), isTrue);
    });

    test('allows sequential cards of same suit', () {
      final game = KlondikeSolitaire();
      final aceHearts = Card('hearts', 'A', faceUp: true);
      final twoHearts = Card('hearts', '2', faceUp: true);
      final threeHearts = Card('hearts', '3', faceUp: true);

      var foundation = [aceHearts];
      expect(game.isValidFoundationMove(twoHearts, foundation), isTrue);

      foundation.add(twoHearts);
      expect(game.isValidFoundationMove(threeHearts, foundation), isTrue);
    });
  });

  group('Game state management', () {
    test('can save and restore game state', () {
      final game = KlondikeSolitaire();
      final initialTableauLength = game.tableau[0].length;

      // Save current state
      game.saveState();

      // Make some changes
      game.tableau[0].add(Card('hearts', 'K', faceUp: true));
      expect(game.tableau[0].length, equals(initialTableauLength + 1));

      // Restore state
      game.undo();
      expect(game.tableau[0].length, equals(initialTableauLength));
    });
  });

  group('Win condition', () {
    test('detects win when all foundations are complete', () {
      final game = KlondikeSolitaire();

      // Manually fill all foundations
      for (var suit in ['hearts', 'diamonds', 'clubs', 'spades']) {
        for (var rank in ranks) {
          game.foundations[suit]!.add(Card(suit, rank, faceUp: true));
        }
      }

      expect(game.checkWinCondition(), isTrue);
    });
  });
}
