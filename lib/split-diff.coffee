{CompositeDisposable, Directory, File} = require 'atom'
DiffViewEditor = require './build-lines'
LoadingView = require './loading-view'
SyncScroll = require './sync-scroll'
configSchema = require "./config-schema"
path = require 'path'

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
  wasEditor1Created: false
  wasEditor2Created: false
  hasGitRepo: false
  process: null
  loadingView: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'split-diff:enable': => @diffPanes()
      'split-diff:next-diff': => @nextDiff()
      'split-diff:prev-diff': => @prevDiff()
      'split-diff:copy-to-right': => @copyChunkToRight()
      'split-diff:copy-to-left': => @copyChunkToLeft()
      'split-diff:disable': => @disable()
      'split-diff:ignore-whitespace': => @toggleIgnoreWhitespace()
      'split-diff:toggle': => @toggle()

  deactivate: ->
    @disable(false)
    @subscriptions.dispose()

  # called by "toggle" command
  # toggles split diff
  toggle: ->
    if @isEnabled
      @disable(true)
    else
      @diffPanes()

  # called by "Disable" command
  # removes diff and sync scroll, disposes of subscriptions
  disable: (displayMsg) ->
    @isEnabled = false

    if @editorSubscriptions?
      @editorSubscriptions.dispose()
      @editorSubscriptions = null

    if @diffViewEditor1?
      if @wasEditor1SoftWrapped
        @diffViewEditor1.enableSoftWrap()
      if @wasEditor1Created
        @diffViewEditor1.cleanUp()

    if @diffViewEditor2?
      if @wasEditor2SoftWrapped
        @diffViewEditor2.enableSoftWrap()
      if @wasEditor2Created
        @diffViewEditor2.cleanUp()

    @_clearDiff()

    @diffChunkPointer = 0
    @isFirstChunkSelect = true
    @wasEditor1SoftWrapped = false
    @wasEditor1Created = false
    @wasEditor2SoftWrapped = false
    @wasEditor2Created = false
    @hasGitRepo = false

    if displayMsg
      atom.notifications.addInfo('Split Diff Disabled', {dismissable: false})

  # called by "toggle ignore whitespace" command
  # toggles ignoring whitespace and refreshes the diff
  toggleIgnoreWhitespace: ->
    @_setConfig('ignoreWhitespace', !@isWhitespaceIgnored)
    @isWhitespaceIgnored = @_getConfig('ignoreWhitespace')

  # called by "Move to next diff" command
  nextDiff: ->
    if !@isFirstChunkSelect
      @diffChunkPointer++
      if @diffChunkPointer >= @linkedDiffChunks.length
        @diffChunkPointer = 0
    else
      @isFirstChunkSelect = false

    @_selectDiffs(@linkedDiffChunks[@diffChunkPointer])

  # called by "Move to previous diff" command
  prevDiff: ->
    if !@isFirstChunkSelect
      @diffChunkPointer--
      if @diffChunkPointer < 0
        @diffChunkPointer = @linkedDiffChunks.length - 1
    else
      @isFirstChunkSelect = false

    @_selectDiffs(@linkedDiffChunks[@diffChunkPointer])

  copyChunkToRight: () ->
    linesToMove = @diffViewEditor1.getCursorDiffLines()
    offset = 0 # keep track of line offset (used when there are multiple chunks being moved)
    for lineRange in linesToMove
      for diffChunk in @linkedDiffChunks
        if lineRange.start.row == diffChunk.oldLineStart
          moveText = @diffViewEditor1.getEditor().getTextInBufferRange([[diffChunk.oldLineStart, 0], [diffChunk.oldLineEnd, 0]])
          @diffViewEditor2.getEditor().setTextInBufferRange([[diffChunk.newLineStart + offset, 0], [diffChunk.newLineEnd + offset, 0]], moveText)
          # offset will be the amount of lines to be copied minus the amount of lines overwritten
          offset += (diffChunk.oldLineEnd - diffChunk.oldLineStart) - (diffChunk.newLineEnd - diffChunk.newLineStart)

  copyChunkToLeft: () ->
    linesToMove = @diffViewEditor2.getCursorDiffLines()
    offset = 0 # keep track of line offset (used when there are multiple chunks being moved)
    for lineRange in linesToMove
      for diffChunk in @linkedDiffChunks
        if lineRange.start.row == diffChunk.newLineStart
          moveText = @diffViewEditor2.getEditor().getTextInBufferRange([[diffChunk.newLineStart, 0], [diffChunk.newLineEnd, 0]])
          @diffViewEditor1.getEditor().setTextInBufferRange([[diffChunk.oldLineStart + offset, 0], [diffChunk.oldLineEnd + offset, 0]], moveText)
          # offset will be the amount of lines to be copied minus the amount of lines overwritten
          offset += (diffChunk.newLineEnd - diffChunk.newLineStart) - (diffChunk.oldLineEnd - diffChunk.oldLineStart)

  # called by the commands enable/toggle to do initial diff
  # sets up subscriptions for auto diff and disabling when a pane is destroyed
  diffPanes: ->
    # in case enable was called again
    @disable(false)

    editors = @_getVisibleEditors()

    @editorSubscriptions = new CompositeDisposable()
    @editorSubscriptions.add editors.editor1.onDidStopChanging =>
      @updateDiff(editors)
    @editorSubscriptions.add editors.editor2.onDidStopChanging =>
      @updateDiff(editors)
    @editorSubscriptions.add editors.editor1.onDidDestroy =>
      @disable(true)
    @editorSubscriptions.add editors.editor2.onDidDestroy =>
      @disable(true)

    @editorSubscriptions.add atom.config.onDidChange 'split-diff', () =>
      @updateDiff(editors)

    # update diff if there is no git repo (no onchange fired)
    if !@hasGitRepo
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
            { 'label': 'Copy to Right', 'command': 'split-diff:copy-to-right'}
            { 'label': 'Copy to Left', 'command': 'split-diff:copy-to-left'}
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
          { 'label': 'Copy to Right', 'command': 'split-diff:copy-to-right'}
          { 'label': 'Copy to Left', 'command': 'split-diff:copy-to-left'}
        ]
      }]
    }

    detailMsg = 'Ignore Whitespace: ' + @isWhitespaceIgnored
    detailMsg += '\nShow Word Diff: ' + @isWordDiffEnabled
    detailMsg += '\nSync Horizontal Scroll: ' + @_getConfig('syncHorizontalScroll')
    atom.notifications.addInfo('Split Diff Enabled', {detail: detailMsg, dismissable: false})

  # called by both diffPanes and the editor subscription to update the diff
  updateDiff: (editors) ->
    @isEnabled = true

    if @process?
      @process.kill()
      @process = null

    @isWhitespaceIgnored = @_getConfig('ignoreWhitespace')

    editorPaths = @_createTempFiles(editors)

    # create the loading view if it doesn't exist yet
    if !@loadingView?
      @loadingView = new LoadingView()
      @loadingView.createModal()
    @loadingView.show()

    # --- kick off background process to compute diff ---
    {BufferedNodeProcess} = require 'atom'
    command = path.resolve __dirname, "./compute-diff.js"
    args = [editorPaths.editor1Path, editorPaths.editor2Path, @isWhitespaceIgnored]
    computedDiff = ''
    theOutput = ''
    stdout = (output) =>
      theOutput = output
      computedDiff = JSON.parse(output)
    stderr = (err) =>
      theOutput = err
    exit = (code) =>
      @loadingView.hide()

      if code == 0
        @_resumeUpdateDiff(editors, computedDiff)
      else
        console.log('BufferedNodeProcess code was ' + code)
        console.log(theOutput)
    @process = new BufferedNodeProcess({command, args, stdout, stderr, exit})
    # --- kick off background process to compute diff ---

  # resumes after the compute diff process returns
  _resumeUpdateDiff: (editors, computedDiff) ->
    @linkedDiffChunks = @_evaluateDiffOrder(computedDiff.chunks)

    @_clearDiff()
    @_displayDiff(editors, computedDiff)

    @isWordDiffEnabled = @_getConfig('diffWords')
    if @isWordDiffEnabled
      @_highlightWordDiff(@linkedDiffChunks)

    syncHorizontalScroll = @_getConfig('syncHorizontalScroll')
    @syncScroll = new SyncScroll(editors.editor1, editors.editor2, syncHorizontalScroll)
    @syncScroll.syncPositions()

  # gets two visible editors
  # auto opens new editors so there are two to diff with
  _getVisibleEditors: ->
    editor1 = null
    editor2 = null

    panes = atom.workspace.getPanes()
    for p in panes
      activeItem = p.getActiveItem()
      if atom.workspace.isTextEditor(activeItem)
        if editor1 == null
          editor1 = activeItem
        else if editor2 == null
          editor2 = activeItem
          break

    # auto open editor panes so we have two to diff with
    if editor1 == null
      editor1 = atom.workspace.buildTextEditor()
      @wasEditor1Created = true
      leftPane = atom.workspace.getActivePane()
      leftPane.addItem(editor1)
    if editor2 == null
      editor2 = atom.workspace.buildTextEditor()
      @wasEditor2Created = true
      editor2.setGrammar(editor1.getGrammar())
      rightPane = atom.workspace.getActivePane().splitRight()
      rightPane.addItem(editor2)

    @_setupGitRepo(editor1, editor2)

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

    # want to scroll a newly created editor to the first editor's position
    if @wasEditor2Created
      atom.views.getView(editor1).focus()

    editors =
      editor1: editor1
      editor2: editor2

    return editors

  _setupGitRepo: (editor1, editor2) ->
    editor1Path = editor1.getPath()
    # only show git changes if the right editor is empty
    if editor1Path? && (editor2.getLineCount() == 1 && editor2.lineTextForBufferRow(0) == '')
      for directory, i in atom.project.getDirectories()
        if editor1Path is directory.getPath() or directory.contains(editor1Path)
          projectRepo = atom.project.getRepositories()[i]
          if projectRepo? && projectRepo.repo?
            relativeEditor1Path = projectRepo.relativize(editor1Path)
            gitHeadText = projectRepo.repo.getHeadBlob(relativeEditor1Path)
            if gitHeadText?
              editor2.setText(gitHeadText)
              @hasGitRepo = true
              break

  # creates temp files so the compute diff process can get the text easily
  _createTempFiles: (editors) ->
    editor1Path = ''
    editor2Path = ''
    tempFolderPath = atom.getConfigDirPath() + '/split-diff'

    editor1Path = tempFolderPath + '/split-diff 1'
    editor1TempFile = new File(editor1Path)
    editor1TempFile.writeSync(editors.editor1.getText())

    editor2Path = tempFolderPath + '/split-diff 2'
    editor2TempFile = new File(editor2Path)
    editor2TempFile.writeSync(editors.editor2.getText())

    editorPaths =
      editor1Path: editor1Path
      editor2Path: editor2Path

    return editorPaths

  _selectDiffs: (diffChunk) ->
    if diffChunk? && @diffViewEditor1? && @diffViewEditor2?
      @diffViewEditor1.deselectAllLines()
      @diffViewEditor2.deselectAllLines()

      if diffChunk.oldLineStart?
        @diffViewEditor1.selectLines(diffChunk.oldLineStart, diffChunk.oldLineEnd)
        @diffViewEditor2.getEditor().scrollToBufferPosition([diffChunk.oldLineStart, 0])
      if diffChunk.newLineStart?
        @diffViewEditor2.selectLines(diffChunk.newLineStart, diffChunk.newLineEnd)
        @diffViewEditor2.getEditor().scrollToBufferPosition([diffChunk.newLineStart, 0])

  # removes diff and sync scroll
  _clearDiff: ->
    if @loadingView?
      @loadingView.hide()

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
  _displayDiff: (editors, computedDiff) ->
    @diffViewEditor1 = new DiffViewEditor(editors.editor1)
    @diffViewEditor2 = new DiffViewEditor(editors.editor2)

    leftColor = @_getConfig('leftEditorColor')
    rightColor = @_getConfig('rightEditorColor')
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

  # puts the chunks into order so nextDiff and prevDiff are in order
  _evaluateDiffOrder: (chunks) ->
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
            oldLineStart: oldLineNumber
            oldLineEnd: oldLineNumber
          diffChunks.push(diffChunk)
        else if prevChunk? && prevChunk.removed?
          diffChunk =
            newLineStart: newLineNumber
            newLineEnd: newLineNumber
            oldLineStart: (oldLineNumber - prevChunk.count)
            oldLineEnd: oldLineNumber
          diffChunks.push(diffChunk)

        prevChunk = null
        oldLineNumber += c.count
        newLineNumber += c.count

    # add the prevChunk if the loop finished
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

    return diffChunks

  # highlights the word differences between lines
  _highlightWordDiff: (chunks) ->
    ComputeWordDiff = require './compute-word-diff'
    leftColor = @_getConfig('leftEditorColor')
    rightColor = @_getConfig('rightEditorColor')
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
          wordDiff = ComputeWordDiff.computeWordDiff(@diffViewEditor1.getEditor().lineTextForBufferRow(c.oldLineStart + i), @diffViewEditor2.getEditor().lineTextForBufferRow(c.newLineStart + i), @isWhitespaceIgnored)
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
              @diffViewEditor1.setWordHighlights(c.oldLineStart + lineRange + j, [{changed: true, value: @diffViewEditor1.getEditor().lineTextForBufferRow(c.oldLineStart + lineRange + j)}], 'added', @isWhitespaceIgnored)
            else
              @diffViewEditor1.setWordHighlights(c.oldLineStart + lineRange + j, [{changed: true, value: @diffViewEditor1.getEditor().lineTextForBufferRow(c.oldLineStart + lineRange + j)}], 'removed', @isWhitespaceIgnored)
          else if (c.newLineEnd - c.newLineStart) > (c.oldLineEnd - c.oldLineStart)
            if rightColor == 'green'
              @diffViewEditor2.setWordHighlights(c.newLineStart + lineRange + j, [{changed: true, value: @diffViewEditor2.getEditor().lineTextForBufferRow(c.newLineStart + lineRange + j)}], 'added', @isWhitespaceIgnored)
            else
              @diffViewEditor2.setWordHighlights(c.newLineStart + lineRange + j, [{changed: true, value: @diffViewEditor2.getEditor().lineTextForBufferRow(c.newLineStart + lineRange + j)}], 'removed', @isWhitespaceIgnored)
      else if c.newLineStart?
        # fully highlight chunks that don't match up to another
        lineRange = c.newLineEnd - c.newLineStart
        for i in [0 ... lineRange] by 1
          if rightColor == 'green'
            @diffViewEditor2.setWordHighlights(c.newLineStart + i, [{changed: true, value: @diffViewEditor2.getEditor().lineTextForBufferRow(c.newLineStart + i)}], 'added', @isWhitespaceIgnored)
          else
            @diffViewEditor2.setWordHighlights(c.newLineStart + i, [{changed: true, value: @diffViewEditor2.getEditor().lineTextForBufferRow(c.newLineStart + i)}], 'removed', @isWhitespaceIgnored)
      else if c.oldLineStart?
        # fully highlight chunks that don't match up to another
        lineRange = c.oldLineEnd - c.oldLineStart
        for i in [0 ... lineRange] by 1
          if leftColor == 'green'
            @diffViewEditor1.setWordHighlights(c.oldLineStart + i, [{changed: true, value: @diffViewEditor1.getEditor().lineTextForBufferRow(c.oldLineStart + i)}], 'added', @isWhitespaceIgnored)
          else
            @diffViewEditor1.setWordHighlights(c.oldLineStart + i, [{changed: true, value: @diffViewEditor1.getEditor().lineTextForBufferRow(c.oldLineStart + i)}], 'removed', @isWhitespaceIgnored)


  _getConfig: (config) ->
    atom.config.get("split-diff.#{config}")

  _setConfig: (config, value) ->
    atom.config.set("split-diff.#{config}", value)
