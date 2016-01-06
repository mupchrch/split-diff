{CompositeDisposable, Emitter, TextEditor, TextBuffer} = require 'atom'
{$} = require 'space-pen'
DiffViewEditor = require './build-lines'
SyncScroll = require './sync-scroll'
configSchema = require "./config-schema"

module.exports = SplitDiff =
  config: configSchema
  subscriptions: null
  diffViewEditor1: null
  diffViewEditor2: null
  editorSubscriptions: null
  isWhitespaceIgnored: false
  linkedDiffChunks: null
  diffChunkPointer: 0
  isFirstChunkSelect: true
  wasEditor1SoftWrapped: false
  wasEditor2SoftWrapped: false

  activate: (state) ->
    @subscriptions = new CompositeDisposable()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'split-diff:diffPanes': => @diffPanes()
      'split-diff:nextDiff': => @nextDiff()
      'split-diff:prevDiff': => @prevDiff()
      'split-diff:disable': => @disable()
      'split-diff:toggleIgnoreWhitespace': => @toggleIgnoreWhitespace()

  deactivate: ->
    @disable()
    @subscriptions.dispose()

  serialize: ->
    @disable()

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

    # unfold all lines so diffs properly align
    editor1.unfoldAll()
    editor2.unfoldAll()

    # turn off soft wrap setting for these editors so diffs properly align
    if editor1.isSoftWrapped()
      @wasEditor1SoftWrapped = true
      editor1.setSoftWrapped(false)
    if editor2.isSoftWrapped()
      @wasEditor2SoftWrapped = true
      editor2.setSoftWrapped(false)

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

    @editorSubscriptions.add atom.config.onDidChange 'split-diff.ignoreWhitespace', ({newValue, oldValue}) =>
      @updateDiff(editors)

    @updateDiff(editors)

    detailMsg = 'Ignore whitespace: ' + @isWhitespaceIgnored
    atom.notifications.addInfo('Split Diff Enabled', {detail: detailMsg})

  # called by both diffPanes and the editor subscription to update the diff
  # creates the scroll sync
  updateDiff: (editors) ->
    @clearDiff()
    @isWhitespaceIgnored = @getConfig('ignoreWhitespace')

    SplitDiffCompute = require './split-diff-compute'
    computedDiff = SplitDiffCompute.computeDiff(editors.editor1.getText(), editors.editor2.getText(), @isWhitespaceIgnored)

    @linkedDiffChunks = @evaluateDiffOrder(computedDiff.chunks)

    @displayDiff(editors, computedDiff)

    @syncScroll = new SyncScroll(editors.editor1, editors.editor2)
    @syncScroll.syncPositions()

  # called by "Disable" command
  # removes diff and sync scroll, disposes of subscriptions
  disable: (displayMsg) ->
    if @wasEditor1SoftWrapped
      @diffViewEditor1.enableSoftWrap()
      @wasEditor1SoftWrapped = false
    if @wasEditor2SoftWrapped
      @diffViewEditor2.enableSoftWrap()
      @wasEditor2SoftWrapped = false

    @clearDiff()
    if @editorSubscriptions
      @editorSubscriptions.dispose()
      @editorSubscriptions = null

    if displayMsg
      atom.notifications.addInfo('Split Diff Disabled')

  # called by "Move to next diff" command
  nextDiff: ->
    if !@isFirstChunkSelect
      @diffChunkPointer++
      if @diffChunkPointer >= @linkedDiffChunks.length
        @diffChunkPointer = 0
    else
      @isFirstChunkSelect = false

    @selectDiffs(@linkedDiffChunks[@diffChunkPointer])

  # called by "Move to previous diff" command
  prevDiff: ->
    if !@isFirstChunkSelect
      @diffChunkPointer--
      if @diffChunkPointer < 0
        @diffChunkPointer = @linkedDiffChunks.length - 1
    else
      @isFirstChunkSelect = false

    @selectDiffs(@linkedDiffChunks[@diffChunkPointer])

  selectDiffs: (diffChunk) ->
    if diffChunk && @diffViewEditor1 && @diffViewEditor2
      @diffViewEditor1.deselectAllLines()
      @diffViewEditor2.deselectAllLines()

      if diffChunk.oldLineStart
        @diffViewEditor1.selectLines(diffChunk.oldLineStart, diffChunk.oldLineEnd)
        @diffViewEditor2.scrollToLine(diffChunk.oldLineStart)
      if diffChunk.newLineStart
        @diffViewEditor2.selectLines(diffChunk.newLineStart, diffChunk.newLineEnd)
        @diffViewEditor2.scrollToLine(diffChunk.newLineStart)

  # removes diff and sync scroll
  clearDiff: ->
    diffChunkPointer = 0
    isFirstChunkSelect = true

    if @diffViewEditor1
      @diffViewEditor1.removeLineOffsets()
      @diffViewEditor1.removeLineHighlights()
      @diffViewEditor1.destroyMarkers()
      @diffViewEditor1 = null

    if @diffViewEditor2
      @diffViewEditor2.removeLineOffsets()
      @diffViewEditor2.removeLineHighlights()
      @diffViewEditor2.destroyMarkers()
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

  evaluateDiffOrder: (chunks) ->
    oldLineNumber = 0
    newLineNumber = 0
    prevChunk = null
    # mapping of chunks between the two panes
    diffChunks = []

    for c in chunks
      if c.added
        if prevChunk && prevChunk.removed
          diffChunk =
            newLineStart: newLineNumber
            newLineEnd: newLineNumber + c.count
            oldLineStart: oldLineNumber - prevChunk.count
            oldLineEnd: oldLineNumber
          diffChunks.push(diffChunk)
          prevChunk = null
        else
          prevChunk = c

        newLineNumber += c.count
      else if c.removed
        if prevChunk && prevChunk.added
          diffChunk =
            newLineStart: newLineNumber - prevChunk.count
            newLineEnd: newLineNumber
            oldLineStart: oldLineNumber
            oldLineEnd: oldLineNumber + c.count
          diffChunks.push(diffChunk)
          prevChunk = null
        else
          prevChunk = c

        oldLineNumber += c.count
      else
        if prevChunk && prevChunk.added
          diffChunk =
            newLineStart: (newLineNumber - prevChunk.count)
            newLineEnd: newLineNumber
          diffChunks.push(diffChunk)
        else if prevChunk && prevChunk.removed
          diffChunk =
            oldLineStart: (oldLineNumber - prevChunk.count)
            oldLineEnd: oldLineNumber
          diffChunks.push(diffChunk)

        prevChunk = null
        oldLineNumber += c.count
        newLineNumber += c.count

    return diffChunks

  # called by "toggle ignore whitespace" command
  # toggles ignoring whitespace and refreshes the diff
  toggleIgnoreWhitespace: ->
    @setConfig('ignoreWhitespace', !@isWhitespaceIgnored)
    @isWhiteSpaceIgnored = @getConfig('ignoreWhitespace')
    @diffPanes()


  getConfig: (config) ->
    atom.config.get("split-diff.#{config}")

  setConfig: (config, value) ->
    atom.config.set("split-diff.#{config}", value)
