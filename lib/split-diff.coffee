{CompositeDisposable, Emitter, TextEditor, TextBuffer} = require 'atom'
{$} = require 'space-pen'
DiffViewEditor = require './build-lines'
SyncScroll = require './sync-scroll'


module.exports = SplitDiff =
  subscriptions: null
  diffViewEditor1: null
  diffViewEditor2: null
  editorSubscriptions: null
  #TODO(mike): serialize/save ignore whitespace setting?
  isWhitespaceIgnored: false

  activate: (state) ->
    @subscriptions = new CompositeDisposable()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'split-diff:diffPanes': => @diffPanes()
      'split-diff:disable': => @disable()
      'split-diff:toggleIgnoreWhitespace': => @toggleIgnoreWhitespace()

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->
    # does nothing for now

  # gets two visible editors
  # auto opens new editors so there are two to diff with
  getVisibleEditors: ->
    editor1 = null
    editor2 = null

    # find visible editors
    atom.workspace.observeTextEditors (editor) =>
      editorView = atom.views.getView(editor)
      $editorView = $(editorView)
      if $editorView.is ':visible'
        if editor1 == null
          editor1 = editor
        else if editor2 == null
          editor2 = editor

    # auto open editor panes so we have two to diff with
    if editor1 == null
      editor1 = new TextEditor()
      leftPane = atom.workspace.getActivePane()
      leftPane.addItem(editor1)
    if editor2 == null
      editor2 = new TextEditor()
      rightPane = atom.workspace.getActivePane().splitRight()
      rightPane.addItem(editor2)

    editors =
      editor1: editor1
      editor2: editor2

    return editors

  # called by the command "Diff Panes" to do initial diff
  # sets up subscriptions for auto diff and disabling when a pane is destroyed
  diffPanes: ->
    @disable(false)

    editors = @getVisibleEditors()

    @editorSubscriptions = new CompositeDisposable()
    @editorSubscriptions.add editors.editor1.onDidStopChanging =>
      @updateDiff(editors)
    @editorSubscriptions.add editors.editor2.onDidStopChanging =>
      @updateDiff(editors)
    @editorSubscriptions.add editors.editor1.onDidDestroy =>
      @disable(true)
    @editorSubscriptions.add editors.editor2.onDidDestroy =>
      @disable(true)

    @updateDiff(editors)

    detailMsg = 'Ignore whitespace: ' + @isWhitespaceIgnored
    atom.notifications.addInfo('Split Diff Enabled', {detail: detailMsg})

  # called by both diffPanes and the editor subscription to update the diff
  # creates the scroll sync
  updateDiff: (editors) ->
    @clearDiff()

    SplitDiffCompute = require './split-diff-compute'
    computedDiff = SplitDiffCompute.computeDiff(editors.editor1.getText(), editors.editor2.getText(), @isWhitespaceIgnored)

    @displayDiff(editors, computedDiff)

    @syncScroll = new SyncScroll(editors.editor1, editors.editor2)
    @syncScroll.syncPositions()

  # called by "Disable" command
  # removes diff and sync scroll, disposes of subscriptions
  disable: (displayMsg) ->
    @clearDiff()
    if @editorSubscriptions
      @editorSubscriptions.dispose()
      @editorSubscriptions = null

    if displayMsg
      atom.notifications.addInfo('Split Diff Disabled')

  # removes diff and sync scroll
  clearDiff: ->
    if @diffViewEditor1
      @diffViewEditor1.removeLineOffsets()
      @diffViewEditor1.removeLineHighlights()
      @diffViewEditor1 = null

    if @diffViewEditor2
      @diffViewEditor2.removeLineOffsets()
      @diffViewEditor2.removeLineHighlights()
      @diffViewEditor2 = null

    if @syncScroll
      @syncScroll.dispose()
      @syncScroll = null

  # displays the diff visually in the editors
  displayDiff: (editors, computedDiff) ->
    @diffViewEditor1 = new DiffViewEditor(editors.editor1)
    @diffViewEditor2 = new DiffViewEditor(editors.editor2)

    @diffViewEditor1.setLineOffsets(computedDiff.oldLineOffsets)
    @diffViewEditor2.setLineOffsets(computedDiff.newLineOffsets)

    @diffViewEditor1.setLineHighlights(undefined, computedDiff.removedLines)
    @diffViewEditor2.setLineHighlights(computedDiff.addedLines, undefined)

  # called by "toggle ignore whitespace" command
  # toggles ignoring whitespace and refreshes the diff
  toggleIgnoreWhitespace: ->
    @isWhitespaceIgnored = !@isWhitespaceIgnored
    @diffPanes()
