# split-diff package

Diffs text between two split panes. The diff is updated when any changes are made. New panes are created if less than two panes exist upon run of the package.

![Split Diff in action](https://github.com/mupchrch/split-diff/raw/master/demo.gif)

## Usage

The **Diff Panes** command is unique; it will create panes as necessary. Here are the situations that could arise:

* If there are **no panes** open, then it will create two *empty* panes to paste your diffs into.
* If there is **one pane** open, then it will diff the pane against a newly created *empty* pane to paste your diff into.
* If there are **two panes** open, then it will diff the two panes.
* If there are **more than two panes** open, then it will diff the first two panes it finds.

To stop diffing, simply close one of the panes *or* use the **Disable** command.

*This package will unfold all folded lines in order to properly align the diff.*
*It will also temporarily turn off soft wrap in the two panes in order to properly align the diff.*

### Commands

| Command | Effect | Default Keymaps |
| ------- | ------ | --------------- |
| `Diff Panes` | Diffs text between two side-by-side panes. Creates panes as needed. | ... |
| `Move to Next Diff` | Scrolls to the next chunk of the diff and highlights it. | `ctrl-alt-n` |
| `Move to Previous Diff` | Scrolls to the previous chunk of the diff and highlights it. | `ctrl-alt-p` |
| `Disable` | Disables the package. Until next time, my friend. | ... |
| `Toggle Ignore Whitespace` | Toggles the Ignore Whitespace setting. | ... |

### Settings

* Ignore Whitespace - Does not diff whitespace when checked.

## Minimap Plugin

Get the [Split Diff minimap plugin](https://atom.io/packages/minimap-split-diff) to make it easier to spot differences!

## Looking for Git Support?

Try the [git-time-machine package](https://atom.io/packages/git-time-machine), which uses Split Diff!
