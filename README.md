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
| `Move to Next Diff` | Highlights the next difference. Moves the cursor so it can be easily copied. | `ctrl-alt-n` |
| `Move to Previous Diff` | Highlights the previous difference. Moves the cursor so it can be easily copied. | `ctrl-alt-p` |
| `Copy to Right` | Copies all differences containing a cursor to the right pane. | ... |
| `Copy to Left` | Copies all differences containing a cursor to the left pane. | ... |

To stop diffing, simply close one of the panes *or* use the `Toggle` command.

### Settings

* **Show Word Diff** - Diffs the words between each line when this box is checked.
* **Ignore Whitespace** - Will not diff whitespace when this box is checked.
* **Mute Notifications** - Mutes all warning notifications when this box is checked.
* **Sync Scrolling** - Syncs the scrolling of the editors.
* **Left Editor Color** - Specifies the highlight color for the left editor.
* **Right Editor Color** - Specifies the highlight color for the right editor.

## Minimap Plugin

Get the [Split Diff minimap plugin](https://atom.io/packages/minimap-split-diff) to make it easier to spot differences!
