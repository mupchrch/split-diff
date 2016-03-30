{CompositeDisposable, Emitter, TextEditor, TextBuffer} = require 'atom'
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
  isWordDiffEnabled: true
  linkedDiffChunks: null
  diffChunkPointer: 0
  isFirstChunkSelect: true
  wasEditor1SoftWrapped: false
  wasEditor2SoftWrapped: false
  isEnabled: false

  activate: (state) ->
    @subscriptions = new CompositeDisposable()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'split-diff:enable': => @diffPanes()
      'split-diff:next-diff': => @nextDiff()
      'split-diff:prev-diff': => @prevDiff()
      'split-diff:disable': => @disable()
      'split-diff:ignore-whitespace': => @toggleIgnoreWhitespace()
      'split-diff:toggle': => @toggle()

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

    panes = atom.workspace.getPanes()
    for p in panes
      activeItem = p.getActiveItem()
      if activeItem instanceof TextEditor
        if editor1 == null
          editor1 = activeItem
        else if editor2 == null
          editor2 = activeItem
          break

    # auto open editor panes so we have two to diff with
    if editor1 == null
      editor1 = new TextEditor()
      leftPane = atom.workspace.getActivePane()
      leftPane.addItem(editor1)
    if editor2 == null
      editor2 = new TextEditor()
      editor2.setGrammar(editor1.getGrammar())
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

  # called by the command "enable" to do initial diff
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

    # update diff on any settings change
    @editorSubscriptions.add atom.config.onDidChange 'split-diff.ignoreWhitespace', ({newValue, oldValue}) =>
      @updateDiff(editors)
    @editorSubscriptions.add atom.config.onDidChange 'split-diff.diffWords', ({newValue, oldValue}) =>
      @updateDiff(editors)
    @editorSubscriptions.add atom.config.onDidChange 'split-diff.leftEditorColor', ({newValue, oldValue}) =>
      @updateDiff(editors)
    @editorSubscriptions.add atom.config.onDidChange 'split-diff.rightEditorColor', ({newValue, oldValue}) =>
      @updateDiff(editors)

    @updateDiff(editors)

    # add application menu items
    @editorSubscriptions.add atom.menu.add [
      {
        'label': 'Packages'
        'submenu': [
          'label': 'Split Diff'
          'submenu': [
            { 'label': 'Ignore Whitespace', 'command': 'split-diff:ignore-whitespace' }
            { 'label': 'Move to Next Diff', 'command': 'split-diff:next-diff' }
            { 'label': 'Move to Previous Diff', 'command': 'split-diff:prev-diff' }
          ]
        ]
      }
    ]
    @editorSubscriptions.add atom.contextMenu.add {
      'atom-text-editor': [{
        'label': 'Split Diff',
        'submenu': [
          { 'label': 'Ignore Whitespace', 'command': 'split-diff:ignore-whitespace' }
          { 'label': 'Move to Next Diff', 'command': 'split-diff:next-diff' }
          { 'label': 'Move to Previous Diff', 'command': 'split-diff:prev-diff' }
        ]
      }]
    }

    detailMsg = 'Ignore Whitespace: ' + @isWhitespaceIgnored
    detailMsg += '\nShow Word Diff: ' + @isWordDiffEnabled
    atom.notifications.addInfo('Split Diff Enabled', {detail: detailMsg, dismissable: false})

  # called by both diffPanes and the editor subscription to update the diff
  # creates the scroll sync
  updateDiff: (editors) ->
    @isEnabled = true
    @clearDiff()
    @isWhitespaceIgnored = @getConfig('ignoreWhitespace')
    @isWordDiffEnabled = @getConfig('diffWords')

    SplitDiffCompute = require './split-diff-compute'
    computedDiff = SplitDiffCompute.computeDiff(editors.editor1.getText(), editors.editor2.getText(), @isWhitespaceIgnored)

    @linkedDiffChunks = @evaluateDiffOrder(computedDiff.chunks)

    @displayDiff(editors, computedDiff)

    if @isWordDiffEnabled
      @highlightWordDiff(SplitDiffCompute, @linkedDiffChunks)

    @syncScroll = new SyncScroll(editors.editor1, editors.editor2)
    @syncScroll.syncPositions()

  # called by "Disable" command
  # removes diff and sync scroll, disposes of subscriptions
  disable: (displayMsg) ->
    @isEnabled = false
    if @wasEditor1SoftWrapped
      @diffViewEditor1.enableSoftWrap()
      @wasEditor1SoftWrapped = false
    if @wasEditor2SoftWrapped
      @diffViewEditor2.enableSoftWrap()
      @wasEditor2SoftWrapped = false

    @clearDiff()
    if @editorSubscriptions?
      @editorSubscriptions.dispose()
      @editorSubscriptions = null

    if displayMsg
      atom.notifications.addInfo('Split Diff Disabled', {dismissable: false})

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
    if diffChunk? && @diffViewEditor1? && @diffViewEditor2?
      @diffViewEditor1.deselectAllLines()
      @diffViewEditor2.deselectAllLines()

      if diffChunk.oldLineStart?
        @diffViewEditor1.selectLines(diffChunk.oldLineStart, diffChunk.oldLineEnd)
        @diffViewEditor2.scrollToLine(diffChunk.oldLineStart)
      if diffChunk.newLineStart?
        @diffViewEditor2.selectLines(diffChunk.newLineStart, diffChunk.newLineEnd)
        @diffViewEditor2.scrollToLine(diffChunk.newLineStart)

  # removes diff and sync scroll
  clearDiff: ->
    @diffChunkPointer = 0
    @isFirstChunkSelect = true

    if @diffViewEditor1?
      @diffViewEditor1.destroyMarkers()
      @diffViewEditor1 = null

    if @diffViewEditor2?
      @diffViewEditor2.destroyMarkers()
      @diffViewEditor2 = null

    if @syncScroll?
      @syncScroll.dispose()
      @syncScroll = null

  # displays the diff visually in the editors
  displayDiff: (editors, computedDiff) ->
    @diffViewEditor1 = new DiffViewEditor(editors.editor1)
    @diffViewEditor2 = new DiffViewEditor(editors.editor2)

    leftColor = @getConfig('leftEditorColor')
    rightColor = @getConfig('rightEditorColor')
    if leftColor == 'green'
      @diffViewEditor1.setLineHighlights(computedDiff.removedLines, 'added')
    else
      @diffViewEditor1.setLineHighlights(computedDiff.removedLines, 'removed')
    if rightColor == 'green'
      @diffViewEditor2.setLineHighlights(computedDiff.addedLines, 'added')
    else
      @diffViewEditor2.setLineHighlights(computedDiff.addedLines, 'removed')

    @diffViewEditor1.setLineOffsets(computedDiff.oldLineOffsets)
    @diffViewEditor2.setLineOffsets(computedDiff.newLineOffsets)

  evaluateDiffOrder: (chunks) ->
    oldLineNumber = 0
    newLineNumber = 0
    prevChunk = null
    # mapping of chunks between the two panes
    diffChunks = []

    for c in chunks
      if c.added?
        if prevChunk? && prevChunk.removed?
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
      else if c.removed?
        if prevChunk? && prevChunk.added?
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
        if prevChunk? && prevChunk.added?
          diffChunk =
            newLineStart: (newLineNumber - prevChunk.count)
            newLineEnd: newLineNumber
          diffChunks.push(diffChunk)
        else if prevChunk? && prevChunk.removed?
          diffChunk =
            oldLineStart: (oldLineNumber - prevChunk.count)
            oldLineEnd: oldLineNumber
          diffChunks.push(diffChunk)

        prevChunk = null
        oldLineNumber += c.count
        newLineNumber += c.count

    return diffChunks

  # highlights the word differences between lines
  highlightWordDiff: (SplitDiffCompute, chunks) ->
    leftColor = @getConfig('leftEditorColor')
    rightColor = @getConfig('rightEditorColor')
    for c in chunks
      # make sure this chunk matches to another
      if c.newLineStart? && c.oldLineStart?
        lineRange = 0
        excessLines = 0
        if (c.newLineEnd - c.newLineStart) < (c.oldLineEnd - c.oldLineStart)
          lineRange = c.newLineEnd - c.newLineStart
          excessLines = (c.oldLineEnd - c.oldLineStart) - lineRange
        else
          lineRange = c.oldLineEnd - c.oldLineStart
          excessLines = (c.newLineEnd - c.newLineStart) - lineRange
        # figure out diff between lines and highlight
        for i in [0 ... lineRange] by 1
          wordDiff = SplitDiffCompute.computeWordDiff(@diffViewEditor1.getLineText(c.oldLineStart + i), @diffViewEditor2.getLineText(c.newLineStart + i), @isWhitespaceIgnored)
          if leftColor == 'green'
            @diffViewEditor1.setWordHighlights(c.oldLineStart + i, wordDiff.removedWords, 'added', @isWhitespaceIgnored)
          else
            @diffViewEditor1.setWordHighlights(c.oldLineStart + i, wordDiff.removedWords, 'removed', @isWhitespaceIgnored)
          if rightColor == 'green'
            @diffViewEditor2.setWordHighlights(c.newLineStart + i, wordDiff.addedWords, 'added', @isWhitespaceIgnored)
          else
            @diffViewEditor2.setWordHighlights(c.newLineStart + i, wordDiff.addedWords, 'removed', @isWhitespaceIgnored)
        # fully highlight extra lines
        for j in [0 ... excessLines] by 1
          # check whether excess line is in editor1 or editor2
          if (c.newLineEnd - c.newLineStart) < (c.oldLineEnd - c.oldLineStart)
            if leftColor == 'green'
              @diffViewEditor1.setWordHighlights(c.oldLineStart + lineRange + j, [{changed: true, value: @diffViewEditor1.getLineText(c.oldLineStart + lineRange + j)}], 'added', @isWhitespaceIgnored)
            else
              @diffViewEditor1.setWordHighlights(c.oldLineStart + lineRange + j, [{changed: true, value: @diffViewEditor1.getLineText(c.oldLineStart + lineRange + j)}], 'removed', @isWhitespaceIgnored)
          else if (c.newLineEnd - c.newLineStart) > (c.oldLineEnd - c.oldLineStart)
            if rightColor == 'green'
              @diffViewEditor2.setWordHighlights(c.newLineStart + lineRange + j, [{changed: true, value: @diffViewEditor2.getLineText(c.newLineStart + lineRange + j)}], 'added', @isWhitespaceIgnored)
            else
              @diffViewEditor2.setWordHighlights(c.newLineStart + lineRange + j, [{changed: true, value: @diffViewEditor2.getLineText(c.newLineStart + lineRange + j)}], 'removed', @isWhitespaceIgnored)
      else if c.newLineStart?
        # fully highlight chunks that don't match up to another
        lineRange = c.newLineEnd - c.newLineStart
        for i in [0 ... lineRange] by 1
          if rightColor == 'green'
            @diffViewEditor2.setWordHighlights(c.newLineStart + i, [{changed: true, value: @diffViewEditor2.getLineText(c.newLineStart + i)}], 'added', @isWhitespaceIgnored)
          else
            @diffViewEditor2.setWordHighlights(c.newLineStart + i, [{changed: true, value: @diffViewEditor2.getLineText(c.newLineStart + i)}], 'removed', @isWhitespaceIgnored)
      else if c.oldLineStart?
        # fully highlight chunks that don't match up to another
        lineRange = c.oldLineEnd - c.oldLineStart
        for i in [0 ... lineRange] by 1
          if leftColor == 'green'
            @diffViewEditor1.setWordHighlights(c.oldLineStart + i, [{changed: true, value: @diffViewEditor1.getLineText(c.oldLineStart + i)}], 'added', @isWhitespaceIgnored)
          else
            @diffViewEditor1.setWordHighlights(c.oldLineStart + i, [{changed: true, value: @diffViewEditor1.getLineText(c.oldLineStart + i)}], 'removed', @isWhitespaceIgnored)

  # called by "toggle ignore whitespace" command
  # toggles ignoring whitespace and refreshes the diff
  toggleIgnoreWhitespace: ->
    @setConfig('ignoreWhitespace', !@isWhitespaceIgnored)
    @isWhitespaceIgnored = @getConfig('ignoreWhitespace')

  # called by "toggle" command
  # toggles split diff
  toggle: ->
    if @isEnabled
      @disable(true)
    else
      @diffPanes()


  getConfig: (config) ->
    atom.config.get("split-diff.#{config}")

  setConfig: (config, value) ->
    atom.config.set("split-diff.#{config}", value)
