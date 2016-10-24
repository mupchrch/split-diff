# split-diff package

Diffs text between two split panes. New panes are created if less than two panes exist upon run of the package.

\*\* **Supports diffing recent git changes!** \*\*

![Split Diff in action](https://github.com/mupchrch/split-diff/raw/master/demo.gif)

## Usage

### Commands

You can call any of these commands from your own custom keybinding, simply override the command in your keymap.cson!

| Command | Effect | Default Keymaps |
| ------- | ------ | --------------- |
| Toggle `split-diff:toggle` | Toggles a diff of the text between two side-by-side panes. Creates panes as necessary. Displays git changes if there is a repository found. | `ctrl-alt-t` |
| Enable `split-diff:enable` | Enables a diff of the text between two side-by-side panes. Creates panes as necessary. Displays git changes if there is a repository found. | ... |
| Disable `split-diff:disable` | Disables a diff. Removes any panes that were created by this package. | ... |
| Ignore Whitespace `split-diff:ignore-whitespace` | Toggles the Ignore Whitespace setting. | ... |
| Move to Next Diff `split-diff:next-diff` | Highlights the next difference. Moves the cursor so it can be easily copied. | `ctrl-alt-n` |
| Move to Previous Diff `split-diff:prev-diff` | Highlights the previous difference. Moves the cursor so it can be easily copied. | `ctrl-alt-p` |
| Copy to Right `split-diff:copy-to-right` | Copies all differences containing a cursor to the right pane. | `ctrl-alt-.` |
| Copy to Left `split-diff:copy-to-left` | Copies all differences containing a cursor to the left pane. | `ctrl-alt-,` |

### Settings

* **Show Word Diff** - Diffs the words between each line when this box is checked.
* **Ignore Whitespace** - Will not diff whitespace when this box is checked.
* **Mute Notifications** - Mutes all warning notifications when this box is checked.
* **Sync Scrolling** - Syncs the scrolling of the editors.
* **Left Editor Color** - Specifies the highlight color for the left editor.
* **Right Editor Color** - Specifies the highlight color for the right editor.

## Minimap Plugin

Get the [Split Diff minimap plugin](https://atom.io/packages/minimap-split-diff) to make it easier to spot differences!
