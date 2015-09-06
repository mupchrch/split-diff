#SplitDiffView = require './split-diff-view'
{CompositeDisposable} = require 'atom'
{$} = require 'space-pen'


module.exports = SplitDiff =
  #splitDiffView: null
  #modalPanel: null
  subscriptions: null
  editor1: null
  editor2: null
  JsDiff: require 'diff'
  markers: []

  activate: (state) ->
    #atom.workspace.observeTextEditors (editor) => console.log editor

    #@splitDiffView = new SplitDiffView(state.splitDiffViewState)
    #@modalPanel = atom.workspace.addModalPanel(item: @splitDiffView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that finds visible text editors
    @subscriptions.add atom.commands.add 'atom-workspace', 'split-diff:getEditors': => @getEditors()

  deactivate: ->
    #@modalPanel.destroy()
    @subscriptions.dispose()
    #@splitDiffView.destroy()

  serialize: ->
    #splitDiffViewState: @splitDiffView.serialize()

  getEditors: ->
    atom.workspace.observeTextEditors (editor) =>
      console.log editor
      editorView = atom.views.getView(editor)
      $editorView = $(editorView)
      if $editorView.is ':visible'
        if @editor1 == null
          @editor1 = editor
          @editor1View = $editorView
        else if @editor2 == null
          @editor2 = editor
          @editor2View = $editorView

    diff = @JsDiff.diffLines(@editor1.getText(), @editor2.getText());
    console.log diff
    lineNumber = 0
    prevSelectionChanged = false;
    for changeObject in diff
      if changeObject.added
        marker = @editor2.markBufferRange([[lineNumber, 0], [lineNumber + changeObject.count, 0]], invalidate: 'never')
        @editor2.decorateMarker(marker, type: 'line', class: 'line-green')
        @markers.push(marker)
        prevSelectionChanged = true
      else if changeObject.removed
        marker = @editor1.markBufferRange([[lineNumber, 0], [lineNumber + changeObject.count, 0]], invalidate: 'never')
        @editor1.decorateMarker(marker, type: 'line', class: 'line-red')
        @markers.push(marker)
        prevSelectionChanged = true
      else
        prevSelectionChanged = false
      if !prevSelectionChanged
        lineNumber = lineNumber + changeObject.count
