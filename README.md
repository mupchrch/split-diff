# split-diff [![Installs!](https://img.shields.io/apm/dm/split-diff.svg?style=flat-square)](https://atom.io/packages/split-diff) [![Version!](https://img.shields.io/apm/v/split-diff.svg?style=flat-square)](https://atom.io/packages/split-diff) [![License](https://img.shields.io/apm/l/split-diff.svg?style=flat-square)](https://github.com/mupchrch/split-diff/blob/master/LICENSE.md)

Diffs text between two split panes. New panes are created if less than two panes exist upon run of the package.

\*\* **Supports diffing recent git changes!** \*\*

![split-diff in action](https://github.com/mupchrch/split-diff/raw/master/demo.gif)

## Minimap Plugin

Get the [split-diff minimap plugin](https://atom.io/packages/minimap-split-diff) to make it easier to spot differences.

## Usage

### Commands

You can call any of these commands from your own custom keybinding, simply override the command in your keymap.cson!

| Command | Effect | Default Keymaps |
| ------- | ------ | --------------- |
| Toggle `split-diff:toggle` | Toggles a diff of the text between two side-by-side panes. Creates panes as necessary. Displays git changes if there is a repository found. | `ctrl-alt-t`,<br>`ctrl-alt-d` (_linux_) |
| Enable `split-diff:enable` | Enables a diff of the text between two side-by-side panes. Creates panes as necessary. Displays git changes if there is a repository found. | ... |
| Disable `split-diff:disable` | Disables a diff. Removes any panes that were created by this package. | ... |
| Set Ignore Whitespace `split-diff:set-ignore-whitespace` | Toggles the Ignore Whitespace setting. | ... |
| Set Auto Diff `split-diff:set-auto-diff` | Toggles the Auto Diff setting. | ... |
| Move to Next Diff `split-diff:next-diff` | Highlights the next difference. Moves the cursor so it can be easily copied. | `ctrl-alt-n` |
| Move to Previous Diff `split-diff:prev-diff` | Highlights the previous difference. Moves the cursor so it can be easily copied. | `ctrl-alt-p` |
| Copy to Right `split-diff:copy-to-right` | Copies all differences containing a cursor to the right pane. | `ctrl-alt-.` |
| Copy to Left `split-diff:copy-to-left` | Copies all differences containing a cursor to the left pane. | `ctrl-alt-,` |

### Settings

* **Auto Diff** - Automatically recalculates the diff when one of the editors changes.
* **Show Word Diff** - Diffs the words between each line when this box is checked.
* **Ignore Whitespace** - Will not diff whitespace when this box is checked.
* **Mute Notifications** - Mutes all warning notifications when this box is checked.
* **Remove Soft Wrap** - Removes soft wrap during diff - restores when finished.
* **Hide Docks** - Hides all docks (Tree View, Github, etc) during diff - shows when finished.
* **Sync Scrolling** - Syncs the scrolling of the editors.
#### Colors
* **Added Color Side** - Which editor (left or right) to highlight as added. The opposite editor will be highlighted as removed.
* **Override Highlight Colors** - Whether to override diff colors derived from the current syntax theme.
* **Added Custom Color** - The color that will be used when overriding added highlight colors.
* **Removed Custom Color** - The color that will be used when overriding removed highlight colors.

### Service API
Packages can consume the split-diff service to do things like enable a diff between two editors.

```js
/**
 * Getter for the marker layers of each editor being diffed.
 * @return {Promise} A promise that resolves to an object containing the marker layers.
 */
getMarkerLayers();

/**
 * Enables split-diff between the two given editors.
 * @param {TextEditor} editor1 - The left editor.
 * @param {TextEditor} editor2 - The right editor.
 * @param {object} options - Options to override any package setting.
 */
diffEditors(editor1, editor2, options);

/**
 * Disables split-diff.
 */
disable();
```
