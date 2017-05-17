module.exports =
  diffWords:
    title: 'Show Word Diff'
    description: 'Diffs the words between each line when this box is checked.'
    type: 'boolean'
    default: true
    order: 1
  ignoreWhitespace:
    title: 'Ignore Whitespace'
    description: 'Will not diff whitespace when this box is checked.'
    type: 'boolean'
    default: false
    order: 2
  muteNotifications:
    title: 'Mute Notifications'
    description: 'Mutes all warning notifications when this box is checked.'
    type: 'boolean'
    default: false
    order: 3
  hideTreeView:
    title: 'Hide Tree View'
    description: 'Hides Tree View during diff - shows when finished.'
    type: 'boolean'
    default: false
    order: 4
  scrollSyncType:
    title: 'Sync Scrolling'
    description: 'Syncs the scrolling of the editors.'
    type: 'string'
    default: 'Vertical + Horizontal'
    enum: ['Vertical + Horizontal', 'Vertical', 'None']
    order: 5
  colors:
    type: 'object'
    properties:
      addedColorSide:
        title: 'Added Color Side'
        description: 'The side that the latest version of the file is on. The added color will be applied to this editor and the removed color will be opposite.'
        type: 'string'
        default: 'left'
        enum: ['left', 'right']
        order: 1
      overrideThemeColors:
        title: 'Override Highlight Colors'
        description: 'Override the line highlight colors (defined by variables in your selected syntax theme) with the colors selected below.'
        type: 'boolean'
        default: false
        order: 2
      addedColor:
        title: 'Added Custom Color'
        description: 'The color that will be used for highlighting added lines when **Override Highlight Colors** is checked.'
        type: 'color'
        default: 'green'
        order: 3
      removedColor:
        title: 'Removed Custom Color'
        description: 'The color that will be used for highlighting removed lines when **Override Highlight Colors** is checked.'
        type: 'color'
        default: 'red'
        order: 4
