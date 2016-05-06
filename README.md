# split-diff package

Diffs text between two split panes. New panes are created if less than two panes exist upon run of the package.

\*\* **Supports diffing recent git changes!** \*\*

![Split Diff in action](https://github.com/mupchrch/split-diff/raw/master/demo.gif)

## Usage

### Commands

| Command | Effect | Default Keymaps |
| ------- | ------ | --------------- |
| `Toggle` | Toggles a diff of the text between two side-by-side panes. Creates panes as necessary. Displays git changes if there is a repository found. | ... |
| `Ignore Whitespace` | Toggles the Ignore Whitespace setting. | ... |
| `Move to Next Diff` | Scrolls to the next chunk of the diff and highlights it. | `ctrl-alt-n` |
| `Move to Previous Diff` | Scrolls to the previous chunk of the diff and highlights it. | `ctrl-alt-p` |
| `Copy to Right` | Copies all diff chunks containing a cursor to the right pane. | ... |
| `Copy to Left` | Copies all diff chunks containing a cursor to the left pane. | ... |

To stop diffing, simply close one of the panes *or* use the `Toggle` command.

### Settings

* **Ignore Whitespace** - Will not diff whitespace when this box is checked.
* **Show Word Diff** - Diffs the words between each line when this box is checked.
* **Sync Horizontal Scroll** - Syncs the horizontal scrolling of the editors.
* **Left Editor Color** - Specifies the highlight color for the left editor.
* **Right Editor Color** - Specifies the highlight color for the right editor.

## Minimap Plugin

Get the [Split Diff minimap plugin](https://atom.io/packages/minimap-split-diff) to make it easier to spot differences!
