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
  scrollSyncType:
    title: 'Sync Scrolling'
    description: 'Syncs the scrolling of the editors.'
    type: 'string'
    default: 'Vertical + Horizontal'
    enum: ['Vertical + Horizontal', 'Vertical', 'None']
    order: 4
  leftEditorColor:
    title: 'Left Editor Color'
    description: 'Specifies the highlight color for the left editor.'
    type: 'string'
    default: 'green'
    enum: ['green', 'red']
    order: 5
  rightEditorColor:
    title: 'Right Editor Color'
    description: 'Specifies the highlight color for the right editor.'
    type: 'string'
    default: 'red'
    enum: ['green', 'red']
    order: 6
