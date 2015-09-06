{CompositeDisposable} = require 'atom'
{$} = require 'space-pen'


module.exports = SplitDiff =
  subscriptions: null
  JsDiff: require 'diff'
  markers: []
  isEnabled: false

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that finds visible text editors
    @subscriptions.add atom.commands.add 'atom-workspace', 'split-diff:toggle': => @toggle()

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->
    #splitDiffViewState: @splitDiffView.serialize()

  toggle: ->
    #TODO(mike): create functions for turn on/off instead of having code in here
    if @isEnabled #turn off
      @removeLineHighlights()
      @isEnabled = false
      console.log 'split-diff disabled'
    else #turn on
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

      #TODO(mike): add error checking on editors here

      diff = @diffLines(editor1, editor2)
      @addLineHighlights(editor1, editor2, diff)
      @isEnabled = true
      console.log 'split-diff enabled'

  diffLines: (editor1, editor2)->
    diff = @JsDiff.diffLines(editor1.getText(), editor2.getText());
    return diff

  addLineHighlights: (editor1, editor2, diff) ->
    lineNumber = 0
    prevSelectionChanged = false;

    for changeObject in diff
      if changeObject.added
        marker = editor2.markBufferRange([[lineNumber, 0], [lineNumber + changeObject.count, 0]], invalidate: 'never')
        editor2.decorateMarker(marker, type: 'line', class: 'line-green')
        @markers.push(marker)
        prevSelectionChanged = true
      else if changeObject.removed
        marker = editor1.markBufferRange([[lineNumber, 0], [lineNumber + changeObject.count, 0]], invalidate: 'never')
        editor1.decorateMarker(marker, type: 'line', class: 'line-red')
        @markers.push(marker)
        prevSelectionChanged = true
      else
        prevSelectionChanged = false

      if !prevSelectionChanged
        lineNumber = lineNumber + changeObject.count

  removeLineHighlights: ->
    marker.destroy() for marker in @markers
    @markers = []
