{CompositeDisposable} = require 'atom'
{$} = require 'space-pen'
DiffViewEditor = require './build-lines.js'


module.exports = SplitDiff =
  subscriptions: null
  JsDiff: require 'diff'
  SplitDiffCompute: require './split-diff-compute.js'
  markers: []
  isEnabled: false

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that finds visible text editors
    @subscriptions.add atom.commands.add 'atom-workspace',
      'split-diff:toggle': => @toggle()

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->
    #splitDiffViewState: @splitDiffView.serialize()

  toggle: ->
    #TODO(mike): create functions for turn on/off instead of having code in here
    if @isEnabled #turn off
      @turnOff()
    else #turn on
      @turnOn()

  addLineHighlights: (editor1, editor2, diff) ->
    editor1LineNum = 0
    editor2LineNum = 0

    for changeObject in diff
      #console.log changeObject
      if changeObject.added
        console.log 'green from ' + (editor1LineNum+1) + ' thru ' + (editor1LineNum+changeObject.count)
        marker = editor2.markBufferRange([[editor1LineNum, 0], [editor1LineNum + changeObject.count, 0]], invalidate: 'never')
        editor2.decorateMarker(marker, type: 'line', class: 'line-green')
        @markers.push(marker)
        editor1LineNum = editor1LineNum + changeObject.count
      else if changeObject.removed
        console.log 'red from ' + (editor2LineNum+1) + ' thru ' + (editor2LineNum+changeObject.count)
        marker = editor1.markBufferRange([[editor2LineNum, 0], [editor2LineNum + changeObject.count, 0]], invalidate: 'never')
        editor1.decorateMarker(marker, type: 'line', class: 'line-red')
        @markers.push(marker)
        editor2LineNum = editor2LineNum + changeObject.count
      else
        editor1LineNum = editor1LineNum + changeObject.count
        editor2LineNum = editor2LineNum + changeObject.count

  removeLineHighlights: ->
    marker.destroy() for marker in @markers
    @markers = []

  turnOn: ->
    editor1 = null
    editor2 = null
    atom.workspace.observeTextEditors (editor) =>
      editorView = atom.views.getView(editor)
      $editorView = $(editorView)
      if $editorView.is ':visible'
        if editor1 == null
          editor1 = editor
        else if editor2 == null
          editor2 = editor

    computedDiff = @SplitDiffCompute.computeDiff(editor1.getText(), editor2.getText())
    console.log computedDiff

    @displayDiff(editor1, editor2, computedDiff)

    @isEnabled = true
    console.log 'split-diff enabled'

  turnOff: ->
    @isEnabled = false
    console.log 'split-diff disabled'

  displayDiff: (editor1, editor2, computedDiff)->
    diffViewEditor1 = new DiffViewEditor(editor1)
    diffViewEditor2 = new DiffViewEditor(editor2)

    diffViewEditor1.setOffsets(computedDiff.oldLineOffsets)
    diffViewEditor2.setOffsets(computedDiff.newLineOffsets)
