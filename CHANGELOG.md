## 1.1.0 - 2016-11-29
* Added ability to diff active file with right click in tree view or tab header #9
* Fixed toggling ignore whitespace via command not updating its state in the footer bar
* Fixed issue where one line editor would always pop notification about differing line endings
* Fixed word diff not working for line diffed against an empty line
* Fixed wrong current selection counter after copying last chunk to other editor
* Fixed poor user experience when auto opening text editors in new panes (Now tries to reuse panes more often instead of greedily creating new ones)
* Large code refactor

## 1.0.6 - 2016-10-24
* Fixed next/prev diff highlight skipping a selection after copying to right/left
* Added keybinding for copy to left/right and scoped it to just the editors #73

## 1.0.5 - 2016-10-05
* Added option to mute warning notifications
* Updated option for scroll syncing to be able to turn off all syncing #68
* Changed package to no longer disable soft wrap while diffing #71

## 1.0.4 - 2016-08-13
* Added keybinding for toggle #64 - thanks moritamori!
* Changed next/prev diff command to toggle package if not enabled #66
* Fixed diff hanging when diffing files containing json/xml #65
* Fixed uncaught exception when pressing copy chunk button before diff finished
* Fixed uncaught exception when pressing next/prev button before diff finished

## 1.0.3 - 2016-06-20
* Reintroduced one second delay to the loading modal #62

## 1.0.2 - 2016-06-03
* Actually fixed line ending normalization for git repo #39 - thanks IceOnFire!

## 1.0.1 - 2016-06-01
* Fixed Uncaught TypeError when trying to highlight word diff #60
* Fixed new pane not using same line endings as first pane for git repo #39
* Fixed last chunk not being the same size which caused misalignment of editors #58

## 1.0.0 - 2016-05-26
* Added a user interface!
* Added help notification when user fails the copy command
* Added new pane opened by package will use same line endings as first pane (except for git panes) #39
* Removed notifications on enable/disable #57
* Changed next/prev diff command to move cursor with it so copy commands are easy #51
* Fixed error when trying to copy last chunk when it didn't have a match #50
* Fixed ignore whitespace not affecting the diff outcome #52
* Fixed Uncaught TypeError when trying to highlight word diff #49
* Fixed pane not getting destroyed if auto-opened editor was last item in it #48

## 0.8.3 - 2016-05-16
* Fixed loading modal appearing forever after diff computes quickly (remove one second delay) #47

## 0.8.2 - 2016-05-16
* Fixed left editor remains soft wrapped #46
* Fixed "Copy to Left" command not working #45

## 0.8.1 - 2016-05-14
* Remove typo in main package file #44 - thanks valepu!

## 0.8.0 - 2016-05-13
* Added "Copy to Right" and "Copy to Left" palette commands, which partially adds #14
* Fixed error when trying to diff using a non-git repo #43

## 0.7.5 - 2016-04-21
* Improved highlighting performance
* Fixed diffing huge files freezes editor #6
* Added loading indicator for files that are taking over one second to diff
* Fixed failure when diffing a file located in a git directory, but isn't tracked #36

## 0.7.4 - 2016-04-16
* Fixed no paste help message for two empty editors #35
* Added close pane and untitled file on toggle #30

## 0.7.3 - 2016-04-11
* Now using placeholder text to display help message #32
* Fixed a bug where diff was updated twice on initial run
* Fixed a bug where scroll was not synced on initial run
* Added setting to sync horizontal scrolling #29

## 0.7.2 - 2016-04-08
* Fixed package disabling immediately in 1.7 beta #28

## 0.7.1 - 2016-04-06
* Fixed next/previous diff starting from beginning of file after change #25

## 0.7.0 - 2016-04-05
* Added ability to display diff of git changes #8
* Fixed deprecations about TextEditor #24 - thanks itiut!
* Fixed reenabling soft wrap throwing an exception

## 0.6.3 - 2016-03-30
* Removed debugging print statement #23 - thanks itiut!

## 0.6.2 - 2016-03-26
* Refactored for #18 to use block decorations for space between chunks
* Changed setting/code for "Diff Line Characters" to "Show Word Diff"
* Fixed a bug where next/prev diff wouldn't be reset between sessions
* Updated demo gif

## 0.6.1 - 2016-03-24
* Added Left/Right Editor Color settings
* Fixed a bug where char diff would be at the wrong position
* Updated application and context menus to be smarter
* Fixed bug #19 - thanks lwblackledge!

## 0.6.0 - 2016-02-26
* Fixed keybindings not binding
* Added highlight colors to gutter line numbers
* Added feature #17 - Highlight line character difference

## 0.5.5 - 2016-02-02
* Removed "Diff Panes" and "Disable" commands from menus (still available from command palette)
* Renamed "Diff Panes" command to "Enable"
* Added "Toggle" command to package and menus

## 0.5.4 - 2016-01-20
* Fixed bug #13 - Missing 'space-pen'

## 0.5.3 - 2016-01-11
* Fixed bug #12 - Uncaught TypeError

## 0.5.2 - 2016-01-05
* Fixed bug #3 - Uncaught TypeError

## 0.5.1 - 2016-01-04
* Fixed bug #11 - Uncaught TypeError
* Removed some items from right click context menu

## 0.5.0 - 2015-12-12
* Added feature #5 - Go to next/previous diff

## 0.4.5 - 2015-11-10
* Fixed bug #2 - Uncaught TypeError

## 0.4.4 - 2015-10-07
* Fixed old markers showing up in minimap-split-diff plugin

## 0.4.3 - 2015-10-06
* Added compatibility for minimap plugin

## 0.4.2 - 2015-09-30
* Fixed bug #1 - Uncaught TypeError

## 0.4.1 - 2015-09-30
* Updated line highlight colors to use theme syntax colors

## 0.4.0 - 2015-09-25
* Added ability to open one or two new panes depending on current amount of panes
* Added ability to unfold all lines when displaying diff so that it is properly aligned
* Added keywords for finding this package easier in atom's package collection

## 0.3.2 - 2015-09-23
* Updated README with demonstration gif

## 0.3.1 - 2015-09-23
* Fixed package compile errors

## 0.3.0 - 2015-09-23
* Fixed scroll sync misalignment upon initial diff
* Added ability to ignore whitespace

## 0.1.0 - First Release
* Every feature added
* Every bug fixed
