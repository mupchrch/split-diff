module.exports =
  ignoreWhitespace:
    title: 'Ignore Whitespace'
    description: 'Will not diff whitespace when this box is checked.'
    type: 'boolean'
    default: false
  diffWords:
    title: 'Show Word Diff'
    description: 'Diffs the words between each line when this box is checked.'
    type: 'boolean'
    default: true
  leftEditorColor:
    title: 'Left Editor Color'
    description: 'Specifies the highlight color for the left editor.'
    type: 'string'
    default: 'green'
    enum: ['green', 'red']
  rightEditorColor:
    title: 'Right Editor Color'
    description: 'Specifies the highlight color for the right editor.'
    type: 'string'
    default: 'red'
    enum: ['green', 'red']
