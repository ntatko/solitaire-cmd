# Command Line Solitaire Example

This is a simple example of how to use the Command Line Solitaire package.

## Installation

```bash
dart pub global activate command_line_solitaire
```

## Usage

If you are using a unix-like operating system, you can run the game by running the following command:

```bash
solitaire
```

If you are using Windows, you can run the game by running the exact same command:

```powershell
solitaire
```

## Controls

- Arrow keys - Move cursor
- Space - Select/Place cards
- 'd' - Draw card
- 'u' - Undo
- 'r' - Redo
- 'a' - Auto-complete
- 'q' - Quit

## Game Rules

Standard Klondike Solitaire rules apply:

- Build foundation piles up by suit (starting with Ace)
- Build tableau piles down by alternating colors
- Only Kings can be placed in empty tableau columns
- Click through the deck to reveal new cards
