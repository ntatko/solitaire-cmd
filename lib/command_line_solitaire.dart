import 'dart:io';
import 'dart:math' show max, Random;
import 'dart:collection';

/// A command-line implementation of Klondike Solitaire.
///
/// This library provides a complete implementation of the classic Klondike Solitaire
/// card game that can be played in a terminal. It features:
/// * Full game rules implementation
/// * Undo/redo functionality
/// * Auto-complete for obvious moves
/// * Color-coded cards and cursor highlighting
/// * Foundation building validation

/// Card suits available in the game, represented by emoji symbols.
const suits = {
  'hearts': '♥️',
  'diamonds': '♦️',
  'clubs': '♣️',
  'spades': '♠️',
};

/// Standard playing card ranks from Ace to King.
const ranks = [
  'A',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'J',
  'Q',
  'K'
];

/// Represents a playing card with a suit, rank, and face-up state.
///
/// Cards can be either face up or face down, and their display changes accordingly.
/// Red suits (hearts and diamonds) are displayed in red when face up.
class Card {
  /// The suit of the card (hearts, diamonds, clubs, or spades).
  final String suit;

  /// The rank of the card (A, 2-10, J, Q, K).
  final String rank;

  /// Whether the card is face up (true) or face down (false).
  bool faceUp;

  /// Creates a new card with the specified suit and rank.
  ///
  /// By default, cards are created face down unless [faceUp] is specified as true.
  Card(this.suit, this.rank, {this.faceUp = false});

  /// The width of a card when displayed in the terminal.
  static const cardWidth = 9;

  /// The height of a card when displayed in the terminal.
  static const cardHeight = 6;

  /// Gets the lines of text that represent this card in the terminal.
  ///
  /// If [showTop] is true, returns the full card display (6 lines).
  /// If false, returns only the top portion (2 lines).
  List<String> getLines({bool showTop = true}) {
    if (!faceUp) {
      // Back of card
      return [
        '╭───────╮',
        '│▒▒▒▒▒▒▒│',
        if (showTop) ...[
          '│▒▒▒▒▒▒▒│',
          '│▒▒▒▒▒▒▒│',
          '│▒▒▒▒▒▒▒│',
          '╰───────╯',
        ]
      ];
    }

    final suitSymbol = suits[suit];
    final color =
        (suit == 'hearts' || suit == 'diamonds') ? '\x1B[31m' : '\x1B[0m';
    final reset = '\x1B[0m';

    // Add extra space for single-digit cards
    final displayRank = rank.length == 1 ? ' $rank' : rank;

    return [
      '╭───────╮',
      '│ $color$displayRank$suitSymbol   $reset│',
      if (showTop) ...[
        '│       │',
        '│       │',
        '│   $color$displayRank$suitSymbol $reset│',
        '╰───────╯',
      ]
    ];
  }

  String getTopView() {
    var lines = getLines(showTop: false);
    return lines.join('\n');
  }

  String getFullView() {
    var lines = getLines(showTop: true);
    return lines.join('\n');
  }
}

/// Represents a position in the game grid using x and y coordinates.
class Position {
  /// The x-coordinate (column) in the game grid.
  final int x;

  /// The y-coordinate (row) in the game grid.
  final int y;

  /// Creates a new position with the specified coordinates.
  Position(this.x, this.y);
}

/// Represents a complete game state that can be saved and restored.
///
/// Used for implementing undo/redo functionality.
class GameState {
  /// The tableau (main playing area) state.
  final List<List<Card>> tableau;

  /// The stock (draw) pile state.
  final List<Card> stock;

  /// The waste (discard) pile state.
  final List<Card> waste;

  /// The foundation piles state, organized by suit.
  final Map<String, List<Card>> foundations;

  /// Creates a new game state with the specified pile states.
  GameState(this.tableau, this.stock, this.waste, this.foundations);

  /// Creates a deep copy of another game state.
  GameState.clone(GameState other)
      : tableau = List<List<Card>>.from(
            other.tableau.map((col) => List<Card>.from(col))),
        stock = List<Card>.from(other.stock),
        waste = List<Card>.from(other.waste),
        foundations = Map<String, List<Card>>.from(other.foundations
            .map((key, value) => MapEntry(key, List<Card>.from(value))));
}

/// The main game class implementing Klondike Solitaire rules and gameplay.
class KlondikeSolitaire {
  /// The deck of cards in the game.
  late List<Card> deck;

  /// The tableau (main playing area) state.
  late List<List<Card>> tableau;

  /// The stock (draw) pile state.
  late List<Card> stock;

  /// The waste (discard) pile state.
  late List<Card> waste;

  /// The foundation piles state, organized by suit.
  late Map<String, List<Card>> foundations;

  /// The current cursor position in the game grid.
  Position cursor = Position(0, 0);

  /// Whether the cursor is currently in the tableau (true) or not (false).
  bool isInTableau = true;

  /// The stack for storing undoable game states.
  final Queue<GameState> undoStack = Queue();

  /// The stack for storing redoable game states.
  final Queue<GameState> redoStack = Queue();

  /// The error message to display to the user, if any.
  String? errorMessage;

  /// Whether the game has been won.
  bool gameWon = false;

  /// The currently selected position in the game grid, if any.
  Position? selectedPosition;

  /// Whether there is currently a selection in the game.
  bool hasSelection = false;

  /// Whether the waste pile is currently selected.
  bool isWasteSelected = false;

  /// Constructs a new Klondike Solitaire game and initializes it.
  KlondikeSolitaire() {
    initializeGame();
  }

  /// Creates a new Klondike Solitaire game and initializes it.
  ///
  /// The game starts with:
  /// * 7 tableau piles with cascading face-down cards and one face-up card each
  /// * A stock pile with the remaining cards
  /// * Empty foundation piles for each suit
  void initializeGame() {
    // Create and shuffle deck
    deck = [];
    for (var suit in suits.keys) {
      for (var rank in ranks) {
        deck.add(Card(suit, rank));
      }
    }
    deck.shuffle(Random());

    // Initialize tableau
    tableau = List.generate(7, (i) => []);
    for (var i = 0; i < 7; i++) {
      for (var j = i; j < 7; j++) {
        tableau[j].add(deck.removeLast());
      }
      // Flip the top card of each pile
      tableau[i].last.faceUp = true;
    }

    // Initialize other game elements
    stock = deck;
    waste = [];
    foundations = {
      'hearts': [],
      'diamonds': [],
      'clubs': [],
      'spades': [],
    };
  }

  /// Checks if a card can be legally moved to a destination pile in the tableau.
  ///
  /// Rules:
  /// * Only Kings can be placed in empty columns
  /// * Cards must alternate colors (red/black)
  /// * Cards must be placed in descending order (e.g., 8 on 9)
  bool isValidMove(Card card, List<Card> destination) {
    log('--- Checking move validity ---');
    log('Moving card: ${card.rank}${suits[card.suit]}');

    if (destination.isEmpty) {
      var isKing = card.rank == 'K';
      log(isKing
          ? '✅ Valid: King to empty column'
          : '❌ Invalid: Only Kings can go to empty columns');
      return isKing;
    }

    var topCard = destination.last;
    log('Destination card: ${topCard.rank}${suits[topCard.suit]}');

    if (!topCard.faceUp) {
      log('❌ Invalid: Destination card is face down');
      return false;
    }

    bool isSourceRed = card.suit == 'hearts' || card.suit == 'diamonds';
    bool isDestRed = topCard.suit == 'hearts' || topCard.suit == 'diamonds';
    if (isSourceRed == isDestRed) {
      log('❌ Invalid: Color match failed - both ${isSourceRed ? "red" : "black"}');
      return false;
    }
    log('✅ Colors alternate correctly');

    int sourceIdx = ranks.indexOf(card.rank);
    int destIdx = ranks.indexOf(topCard.rank);
    bool isConsecutive = sourceIdx + 1 == destIdx;
    log('Rank check: ${card.rank} ($sourceIdx) -> ${topCard.rank} ($destIdx)');
    log(isConsecutive
        ? '✅ Valid: Ranks are consecutive'
        : '❌ Invalid: Ranks are not consecutive');

    return isConsecutive;
  }

  /// Checks if a card can be legally moved to a foundation pile.
  ///
  /// Rules:
  /// * Only Aces can start a foundation pile
  /// * Cards must be of the same suit
  /// * Cards must be placed in ascending order (A, 2, 3, ...)
  bool isValidFoundationMove(Card card, List<Card> foundation) {
    if (foundation.isEmpty) {
      return card.rank == 'A';
    }

    var topCard = foundation.last;
    int sourceIdx = ranks.indexOf(card.rank);
    int destIdx = ranks.indexOf(topCard.rank);
    return sourceIdx == destIdx + 1;
  }

  void moveCards(Position from, Position to) {
    // Handle tableau moves
    if (isInTableau && to.x < 7) {
      var sourceColumn = tableau[from.x];
      if (from.y >= sourceColumn.length) {
        return;
      }

      // Skip if trying to move to the same column
      if (from.x == to.x) {
        showError('Cannot move cards to the same column');
        return;
      }

      var sourceCard = sourceColumn[from.y];
      var destColumn = tableau[to.x];

      if (!sourceCard.faceUp) {
        showError('Can only move face-up cards');
        return;
      }

      if (destColumn.isEmpty) {
        if (sourceCard.rank != 'K') {
          showError('Only Kings can be placed in empty columns');
          return;
        }
      } else {
        var topCard = destColumn.last;
        bool isSourceRed =
            sourceCard.suit == 'hearts' || sourceCard.suit == 'diamonds';
        bool isDestRed = topCard.suit == 'hearts' || topCard.suit == 'diamonds';

        if (isSourceRed == isDestRed) {
          showError('Cards must alternate colors (red/black)');
          return;
        }

        int sourceIdx = ranks.indexOf(sourceCard.rank);
        int destIdx = ranks.indexOf(topCard.rank);
        if (sourceIdx + 1 != destIdx) {
          showError('Cards must be in descending order (e.g., 8 on 9)');
          return;
        }
      }

      saveState();
      tableau[to.x].addAll(sourceColumn.sublist(from.y));
      sourceColumn.removeRange(from.y, sourceColumn.length);

      if (sourceColumn.isNotEmpty && !sourceColumn.last.faceUp) {
        sourceColumn.last.faceUp = true;
      }
    }

    // Check win condition after every move
    if (checkWinCondition()) {
      gameWon = true;
    }
  }

  /// Draws a card from the stock pile and adds it to the waste pile.
  ///
  /// If the stock pile is empty, it will recycle the waste pile back to the stock.
  void drawCard() {
    if (stock.isEmpty) {
      // When recycling, make sure all cards are face down in stock
      stock = waste.reversed.map((card) {
        card.faceUp = false; // Set all cards face down
        return card;
      }).toList();
      waste.clear();
      log('Recycled waste pile back to stock');
      return;
    }

    var card = stock.removeLast();
    card.faceUp = true; // Only flip when moving to waste
    waste.add(card);
    log('Drew ${card.rank}${suits[card.suit]}');
  }

  /// Handles user input for game controls.
  ///
  /// Controls:
  /// * Arrow keys - Move cursor
  /// * Space - Select/Place cards
  /// * 'd' - Draw card
  /// * 'u' - Undo
  /// * 'r' - Redo
  /// * 'a' - Auto-complete
  /// * 'q' - Quit
  void handleInput() {
    var key = stdin.readByteSync();
    switch (key) {
      case 65: // Up arrow
        if (isInTableau) {
          var newY = cursor.y - 1;
          while (newY >= 0 && !tableau[cursor.x][newY].faceUp) {
            newY--;
          }
          if (newY >= 0) {
            cursor = Position(cursor.x, newY);
          } else if (cursor.y == 0) {
            isInTableau = false;
            cursor = Position(0, 0);
          }
        }
        break;

      case 66: // Down arrow
        if (!isInTableau) {
          // Keep selection state when moving down
          var wasSelected = hasSelection;
          var oldSelectedPosition = selectedPosition;

          isInTableau = true;
          var col = tableau[0];
          var newY = 0;
          while (newY < col.length && !col[newY].faceUp) {
            newY++;
          }
          cursor = Position(0, newY < col.length ? newY : 0);

          // Restore selection if it was from waste
          if (wasSelected && oldSelectedPosition?.x == 1) {
            selectedPosition = oldSelectedPosition;
            hasSelection = true;
          }
        } else {
          var maxY = tableau[cursor.x].length - 1;
          var newY = cursor.y + 1;
          while (newY <= maxY && !tableau[cursor.x][newY].faceUp) {
            newY++;
          }
          if (newY <= maxY) {
            cursor = Position(cursor.x, newY);
          }
        }
        break;

      case 67: // Right arrow
        if (isInTableau) {
          // Wrap around in tableau
          var newX = (cursor.x + 1) % 7;
          var newColumn = tableau[newX];
          var newY = cursor.y;
          while (newY < newColumn.length && !newColumn[newY].faceUp) {
            newY++;
          }
          if (newY >= newColumn.length) {
            newY = cursor.y;
            while (newY >= 0 &&
                (newY >= newColumn.length || !newColumn[newY].faceUp)) {
              newY--;
            }
          }
          cursor = Position(newX, max(0, newY));
        } else {
          // Wrap around in top row (0-5 for stock, waste, and foundations)
          cursor = Position((cursor.x + 1) % 6, 0);
        }
        break;

      case 68: // Left arrow
        if (isInTableau) {
          // Wrap around in tableau
          var newX = cursor.x - 1;
          if (newX < 0) newX = 6; // Wrap to rightmost column
          var newColumn = tableau[newX];
          var newY = cursor.y;
          while (newY < newColumn.length && !newColumn[newY].faceUp) {
            newY++;
          }
          if (newY >= newColumn.length) {
            newY = cursor.y;
            while (newY >= 0 &&
                (newY >= newColumn.length || !newColumn[newY].faceUp)) {
              newY--;
            }
          }
          cursor = Position(newX, max(0, newY));
        } else {
          // Wrap around in top row
          cursor = Position(cursor.x - 1 < 0 ? 5 : cursor.x - 1, 0);
        }
        break;

      case 32: // Space
        if (!hasSelection && !isWasteSelected) {
          // If nothing is selected, try to select current position
          if (!isInTableau && cursor.x == 1 && waste.isNotEmpty) {
            // Select waste pile card
            isWasteSelected = true;
            isInTableau = true;
            // Find appropriate position in first tableau column
            var col = tableau[0];
            cursor = Position(0, col.isEmpty ? 0 : col.length - 1);
          } else if (isInTableau && cursor.y < tableau[cursor.x].length) {
            var card = tableau[cursor.x][cursor.y];
            if (card.faceUp) {
              selectedPosition = Position(cursor.x, cursor.y);
              hasSelection = true;
            }
          }
        } else {
          // If we have a selection, try to move it
          if (isWasteSelected) {
            moveFromWaste(cursor);
            isWasteSelected = false;
          } else if (selectedPosition != null) {
            moveCards(selectedPosition!, cursor);
            selectedPosition = null;
            hasSelection = false;
          }
        }
        break;

      case 100: // 'd' key
        drawCard();
        break;

      case 117: // 'u' key
        undo();
        break;

      case 114: // 'r' key
        redo();
        break;

      case 97: // 'a' key
        autoComplete();
        break;

      case 113: // 'q' key
        exit(0);

      case 27: // Escape key
        break;

      case 109: // 'm' key
        autoMoveCard();
        break;
    }
  }

  /// Displays the current state of the game.
  ///
  /// This includes the tableau, foundations, stock, waste, and controls.
  void display() {
    stdout.write('\x1B[2J\x1B[H');

    if (gameWon) {
      stdout.writeln('\n');
      stdout.writeln('    🎉 🎉 🎉 🎉 🎉 🎉 🎉 🎉 🎉');
      stdout.writeln('    Congratulations! You\'ve won!');
      stdout.writeln('    🎉 🎉 🎉 🎉 🎉 🎉 🎉 🎉 🎉');
      stdout.writeln('\n    Press any key to exit');

      // Wait for keypress and exit
      stdin.readByteSync();
      exit(0);
    }

    // Print top row cards
    var topRowCards = List.generate(6, (i) {
      if (i < 4) {
        // Foundations (right to left)
        var suit = ['spades', 'hearts', 'diamonds', 'clubs'][i];
        var cards = foundations[suit]!;
        var display = cards.isEmpty
            ? [
                '╭───────╮',
                '│       │',
                '│       │',
                '│       │',
                '│       │',
                '╰───────╯'
              ]
            : cards.last.getLines(showTop: true);

        if (!isInTableau && cursor.x == i + 2) {
          display = display.map((line) => addHighlight(line)).toList();
        }
        return display;
      } else if (i == 4) {
        // Stock
        var display = stock.isEmpty
            ? [
                '╭───────╮',
                '│       │',
                '│       │',
                '│       │',
                '│       │',
                '╰───────╯'
              ]
            : stock.last.getLines(showTop: true);
        if (!isInTableau && cursor.x == 0) {
          display = display.map((line) => addHighlight(line)).toList();
        }
        return display;
      } else {
        // Waste
        var display = waste.isEmpty
            ? [
                '╭───────╮',
                '│       │',
                '│       │',
                '│       │',
                '│       │',
                '╰───────╯'
              ]
            : waste.last.getLines(showTop: true);

        // Highlight waste pile
        if (!isInTableau && cursor.x == 1) {
          display = display.map((line) => addHighlight(line)).toList();
        }
        if (isWasteSelected) {
          display = display.map((line) => addBlueHighlight(line)).toList();
        }
        return display;
      }
    });

    // Print top row cards
    for (var row = 0; row < 6; row++) {
      // Print foundations (right to left)
      for (var i = 0; i < 4; i++) {
        stdout.write('${topRowCards[i][row]} ');
      }
      // Add extra card-width gap
      stdout.write(' ' * 10);
      // Print draw piles
      for (var i = 4; i < 6; i++) {
        stdout.write('${topRowCards[i][row]} ');
      }
      stdout.writeln();
    }

    stdout.writeln('\n(Press \'d\' to draw)');

    stdout.writeln('\nTableau:');
    displayTableau();

    stdout.writeln('\nControls:');
    stdout.writeln(
        'Arrow keys - Move cursor    Space - Select/Place cards    m - Auto-move card');
    stdout.writeln(
        'd - Draw card    u - Undo    r - Redo    a - Auto-complete    q - Quit');

    if (errorMessage != null) {
      stdout.writeln('\n\x1B[31m$errorMessage\x1B[0m');
    }
  }

  void displayTableau() {
    int maxHeight = tableau.map((column) => column.length).reduce(max);

    for (var row = 0; row < maxHeight; row++) {
      for (var cardLine = 0; cardLine < 2; cardLine++) {
        for (var col = 0; col < 7; col++) {
          if (row < tableau[col].length) {
            var card = tableau[col][row];
            var lines = card.getLines(showTop: false);
            var line = cardLine < lines.length ? lines[cardLine] : ' ' * 9;

            // Show selection from tableau
            if (hasSelection &&
                selectedPosition!.x == col &&
                row >= selectedPosition!.y &&
                selectedPosition!.x != 1) {
              // Don't highlight tableau when waste is selected
              line = addBlueHighlight(line);
            }
            // Always show cursor in tableau when isInTableau is true
            if (isInTableau && cursor.x == col && cursor.y == row) {
              line = addHighlight(line);
            }

            stdout.write('$line ');
          } else {
            // Show highlighted empty space when cursor is here
            var emptySpace = ' ' * 9;
            if (isInTableau && cursor.x == col && cursor.y == row) {
              emptySpace = '╭───────╮';
              if (cardLine == 1) {
                emptySpace = '╰───────╯';
              }
              emptySpace = addHighlight(emptySpace);
            }
            stdout.write('$emptySpace ');
          }
        }
        stdout.writeln();
      }
    }
  }

  /// Adds a highlight to the given text.
  ///
  /// This is used to highlight the cursor position in the tableau.
  String addHighlight(String text) {
    return text
        .split('\n')
        .map((line) => '\x1B[47m\x1B[30m$line\x1B[0m')
        .join('\n');
  }

  /// Adds a blue highlight to the given text.
  ///
  /// This is used to highlight the waste pile selection.
  String addBlueHighlight(String text) {
    return text
        .split('\n')
        .map((line) => '\x1B[44m\x1B[37m$line\x1B[0m')
        .join('\n');
  }

  /// Starts the game loop and handles user input.
  ///
  /// Controls:
  /// * Arrow keys - Move cursor
  /// * Space - Select/Place cards
  /// * 'd' - Draw card
  /// * 'u' - Undo
  /// * 'r' - Redo
  /// * 'a' - Auto-complete
  /// * 'q' - Quit
  void start() {
    // Make stdin raw mode for arrow key handling
    stdin.echoMode = false;
    stdin.lineMode = false;

    while (true) {
      display();
      handleInput();
    }
  }

  void saveState() {
    undoStack.addLast(GameState.clone(
      GameState(tableau, stock, waste, foundations),
    ));
    redoStack.clear();
  }

  void undo() {
    if (undoStack.isEmpty) {
      showError('Nothing to undo');
      return;
    }
    redoStack.addLast(GameState.clone(
      GameState(tableau, stock, waste, foundations),
    ));
    var previousState = undoStack.removeLast();
    restoreState(previousState);
    log('Undid last move');
  }

  /// Redoes the last undone move.
  void redo() {
    if (redoStack.isEmpty) {
      showError('Nothing to redo');
      return;
    }
    undoStack.addLast(GameState.clone(
      GameState(tableau, stock, waste, foundations),
    ));
    var nextState = redoStack.removeLast();
    restoreState(nextState);
    log('Redid last move');
  }

  /// Restores the game state from a previous state.
  void restoreState(GameState state) {
    tableau = state.tableau;
    stock = state.stock;
    waste = state.waste;
    foundations = state.foundations;
  }

  /// Displays an error message to the user.
  ///
  /// This message will be displayed for 2 seconds before being cleared.
  void showError(String message) {
    errorMessage = message;
    Future.delayed(Duration(seconds: 2), () {
      errorMessage = null;
    });
  }

  /// Checks if the game has been won.
  ///
  /// This is done by checking if all foundation piles have 13 cards.
  bool checkWinCondition() {
    bool isWon = foundations.values.every((pile) => pile.length == 13);
    if (isWon && !gameWon) {
      gameWon = true;
      saveState(); // Save the winning state
    }
    return isWon;
  }

  /// Attempts to automatically complete obvious moves.
  ///
  /// This will move cards to the foundation piles when it's clearly safe to do so,
  /// helping to speed up end-game play.
  void autoComplete() {
    bool madeMove;
    int moveCount = 0;
    do {
      madeMove = false;

      // Try to move cards to foundations
      for (var i = 0; i < tableau.length; i++) {
        if (tableau[i].isEmpty) continue;
        var card = tableau[i].last;
        if (!card.faceUp) continue;

        var foundation = foundations[card.suit]!;
        if (isValidFoundationMove(card, foundation)) {
          saveState();
          foundation.add(tableau[i].removeLast());
          if (tableau[i].isNotEmpty && !tableau[i].last.faceUp) {
            tableau[i].last.faceUp = true;
          }
          madeMove = true;
          break;
        }
      }

      // Try to move waste card to foundation
      if (!madeMove && waste.isNotEmpty) {
        var card = waste.last;
        var foundation = foundations[card.suit]!;
        if (isValidFoundationMove(card, foundation)) {
          saveState();
          foundation.add(waste.removeLast());
          madeMove = true;
        }
      }

      if (madeMove) moveCount++;
    } while (madeMove);

    if (moveCount > 0) {
      log('Auto-completed $moveCount moves');
    } else {
      log('No moves available for auto-complete');
    }
  }

  /// Moves a card to a foundation pile.
  ///
  /// This function checks if the move is valid and then performs the move.
  void moveToFoundation(Card card, List<Card> source, int sourceIndex) {
    var foundation = foundations[card.suit]!;
    if (foundation.isEmpty && card.rank != 'A') {
      showError('Only Aces can start a foundation pile');
      return;
    } else if (foundation.isNotEmpty) {
      var topCard = foundation.last;
      int sourceIdx = ranks.indexOf(card.rank);
      int destIdx = ranks.indexOf(topCard.rank);
      if (sourceIdx != destIdx + 1) {
        showError(
            'Cards in foundation must be in ascending order of same suit');
        return;
      }
    }

    saveState();
    foundation.add(source.removeLast());
    if (source.isNotEmpty && !source.last.faceUp) {
      source.last.faceUp = true;
    }

    // Check win condition after foundation move
    checkWinCondition();
  }

  void log(String message) {
    // No-op - logging removed

    // print(message);
  }

  /// Moves a card from the waste pile to the tableau.
  ///
  /// This function checks if the move is valid and then performs the move.
  void moveFromWaste(Position to) {
    if (waste.isEmpty) return;
    if (to.x >= 7) return;

    var card = waste.last;
    var destColumn = tableau[to.x];

    if (destColumn.isEmpty) {
      if (card.rank != 'K') {
        showError('Only Kings can be placed in empty columns');
        return;
      }
    } else {
      var topCard = destColumn.last;
      bool isSourceRed = card.suit == 'hearts' || card.suit == 'diamonds';
      bool isDestRed = topCard.suit == 'hearts' || topCard.suit == 'diamonds';

      if (isSourceRed == isDestRed) {
        showError('Cards must alternate colors (red/black)');
        return;
      }

      int sourceIdx = ranks.indexOf(card.rank);
      int destIdx = ranks.indexOf(topCard.rank);
      if (sourceIdx + 1 != destIdx) {
        showError('Cards must be in descending order (e.g., 8 on 9)');
        return;
      }
    }

    saveState();
    tableau[to.x].add(waste.removeLast());

    // Check win condition after move
    checkWinCondition();
  }

  /// Automatically moves the card under the cursor to any valid position.
  ///
  /// This will try to move the card in this order:
  /// 1. To a foundation pile if valid
  /// 2. To a tableau pile if valid
  /// Returns true if a move was made.
  void autoMoveCard() {
    // Can't move if no card is under cursor
    if (isInTableau) {
      if (cursor.y >= tableau[cursor.x].length) return;
      var card = tableau[cursor.x][cursor.y];
      if (!card.faceUp) return;

      // First try foundation
      var foundation = foundations[card.suit]!;
      if (isValidFoundationMove(card, foundation)) {
        saveState();
        foundation.add(tableau[cursor.x].removeLast());
        if (tableau[cursor.x].isNotEmpty && !tableau[cursor.x].last.faceUp) {
          tableau[cursor.x].last.faceUp = true;
        }
        log('Auto-moved ${card.rank}${suits[card.suit]} to foundation');
        return;
      }

      // Then try tableau
      for (var i = 0; i < 7; i++) {
        if (i == cursor.x) continue; // Skip current column
        if (isValidMove(card, tableau[i])) {
          saveState();
          tableau[i].addAll(tableau[cursor.x].sublist(cursor.y));
          tableau[cursor.x].removeRange(cursor.y, tableau[cursor.x].length);
          if (tableau[cursor.x].isNotEmpty && !tableau[cursor.x].last.faceUp) {
            tableau[cursor.x].last.faceUp = true;
          }
          log('Auto-moved ${card.rank}${suits[card.suit]} to tableau column ${i + 1}');
          return;
        }
      }
    } else if (cursor.x == 1 && waste.isNotEmpty) {
      // Try to move from waste pile
      var card = waste.last;

      // First try foundation
      var foundation = foundations[card.suit]!;
      if (isValidFoundationMove(card, foundation)) {
        saveState();
        foundation.add(waste.removeLast());
        log('Auto-moved ${card.rank}${suits[card.suit]} to foundation');
        return;
      }

      // Then try tableau
      for (var i = 0; i < 7; i++) {
        if (isValidMove(card, tableau[i])) {
          saveState();
          tableau[i].add(waste.removeLast());
          log('Auto-moved ${card.rank}${suits[card.suit]} to tableau column ${i + 1}');
          return;
        }
      }
    }

    showError('No valid moves available for this card');
  }
}

void main() {
  final game = KlondikeSolitaire();
  game.start();
}
