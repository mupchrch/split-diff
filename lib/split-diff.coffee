{CompositeDisposable, Emitter, TextEditor, TextBuffer} = require 'atom'
{$} = require 'space-pen'
DiffViewEditor = require './build-lines'
SyncScroll = require './sync-scroll'


module.exports = SplitDiff =
  subscriptions: null
  isEnabled: false
  diffViewEditor1: null
  diffViewEditor2: null
  editorSubscriptions: null
  #TODO(mike): serialize/save ignore whitespace setting
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
    #splitDiffViewState: @splitDiffView.serialize()

  getVisibleEditors: ->
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

  diffPanes: ->
    editors = @getVisibleEditors()

    #if editors.editor1 == null || editors.editor2 == null
    #  atom.notifications.addInfo('Split Diff', {detail: 'You must have two panes open.'})
    #  rightPane = atom.workspace.getActivePane().splitRight()
    #  rightPane.addItem(new TextEditor())
    #  return

    @editorSubscriptions = new CompositeDisposable()
    @editorSubscriptions.add editors.editor1.onDidStopChanging =>
      @updateDiff(editors)
    @editorSubscriptions.add editors.editor2.onDidStopChanging =>
      @updateDiff(editors)
    @editorSubscriptions.add editors.editor1.onDidDestroy =>
      @disable()
    @editorSubscriptions.add editors.editor2.onDidDestroy =>
      @disable()

    @updateDiff(editors)

    detailMsg = 'Ignore whitespace: ' + @isWhitespaceIgnored
    atom.notifications.addInfo('Split Diff Enabled', {detail: detailMsg})

  updateDiff: (editors) ->
    @clearDiff()

    SplitDiffCompute = require './split-diff-compute'
    computedDiff = SplitDiffCompute.computeDiff(editors.editor1.getText(), editors.editor2.getText(), @isWhitespaceIgnored)

    @displayDiff(editors, computedDiff)

    @syncScroll = new SyncScroll(editors.editor1, editors.editor2)
    @syncScroll.syncPositions()

    @isEnabled = true

  disable: ->
    @clearDiff()
    if @isEnabled
      @editorSubscriptions.dispose()
      @editorSubscriptions = null
      @isEnabled = false

    atom.notifications.addInfo('Split Diff Disabled')

  clearDiff: ->
    if @isEnabled
      @diffViewEditor1.removeLineOffsets()
      @diffViewEditor1.removeLineHighlights()

      @diffViewEditor2.removeLineOffsets()
      @diffViewEditor2.removeLineHighlights()

      @syncScroll.dispose()
      @syncScroll = null

      @diffViewEditor1 = null
      @diffViewEditor2 = null

  displayDiff: (editors, computedDiff) ->
    @diffViewEditor1 = new DiffViewEditor(editors.editor1)
    @diffViewEditor2 = new DiffViewEditor(editors.editor2)

    @diffViewEditor1.setLineOffsets(computedDiff.oldLineOffsets)
    @diffViewEditor2.setLineOffsets(computedDiff.newLineOffsets)

    @diffViewEditor1.setLineHighlights(undefined, computedDiff.removedLines)
    @diffViewEditor2.setLineHighlights(computedDiff.addedLines, undefined)

  toggleIgnoreWhitespace: ->
    @isWhitespaceIgnored = !@isWhitespaceIgnored
    @diffPanes()
