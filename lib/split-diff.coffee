{CompositeDisposable, Directory, File} = require 'atom'
DiffView = require './diff-view'
LoadingView = require './ui/loading-view'
FooterView = require './ui/footer-view'
SyncScroll = require './sync-scroll'
configSchema = require './config-schema'
path = require 'path'

module.exports = SplitDiff =
  diffView: null
  config: configSchema
  subscriptions: null
  editorSubscriptions: null
  isEnabled: false
  wasEditor1Created: false
  wasEditor2Created: false
  hasGitRepo: false
  process: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'split-diff:enable': => @diffPanes()
      'split-diff:next-diff': =>
        if @isEnabled
          @nextDiff()
        else
          @diffPanes()
      'split-diff:prev-diff': =>
        if @isEnabled
          @prevDiff()
        else
          @diffPanes()
      'split-diff:copy-to-right': =>
        if @isEnabled
          @copyToRight()
      'split-diff:copy-to-left': =>
        if @isEnabled
          @copyToLeft()
      'split-diff:disable': => @disable()
      'split-diff:ignore-whitespace': => @toggleIgnoreWhitespace()
      'split-diff:toggle': => @toggle()

  deactivate: ->
    @disable()
    @subscriptions.dispose()

  # called by "toggle" command
  # toggles split diff
  toggle: ->
    if @isEnabled
      @disable()
    else
      @diffPanes()

  # called by "Disable" command
  # removes diff and sync scroll, disposes of subscriptions
  disable: () ->
    @isEnabled = false

    # remove listeners
    if @editorSubscriptions?
      @editorSubscriptions.dispose()
      @editorSubscriptions = null

    if @diffView?
      if @wasEditor1Created
        @diffView.cleanUpEditor(1)
      if @wasEditor2Created
        @diffView.cleanUpEditor(2)
      @diffView.destroy()
      @diffView = null

    # remove views
    if @footerView?
      @footerView.destroy()
      @footerView = null
    if @loadingView?
      @loadingView.destroy()
      @loadingView = null

    if @syncScroll?
      @syncScroll.dispose()
      @syncScroll = null

    # reset all variables
    @wasEditor1Created = false
    @wasEditor2Created = false
    @hasGitRepo = false

  # called by "toggle ignore whitespace" command
  # toggles ignoring whitespace and refreshes the diff
  toggleIgnoreWhitespace: ->
    isWhitespaceIgnored = @_getConfig('ignoreWhitespace')
    @_setConfig('ignoreWhitespace', !isWhitespaceIgnored)
    @footerView?.setIgnoreWhitespace(!isWhitespaceIgnored)

  # called by "Move to next diff" command
  nextDiff: ->
    if @diffView?
      selectedIndex = @diffView.nextDiff()
      if @footerView?
        @footerView.showSelectionCount( selectedIndex + 1 )

  # called by "Move to previous diff" command
  prevDiff: ->
    if @diffView?
      selectedIndex = @diffView.prevDiff()
      if @footerView?
        @footerView.showSelectionCount( selectedIndex + 1 )

  # called by "Copy to right" command
  copyToRight: ->
    if @diffView?
      @diffView.copyToRight()

  # called by "Copy to left" command
  copyToLeft: ->
    if @diffView?
      @diffView.copyToLeft()

  # called by the commands enable/toggle to do initial diff
  # sets up subscriptions for auto diff and disabling when a pane is destroyed
  diffPanes: ->
    # in case enable was called again
    @disable()

    @editorSubscriptions = new CompositeDisposable()

    editors = @_getVisibleEditors()
    @diffView = new DiffView(editors)

    # add listeners
    @editorSubscriptions.add editors.editor1.onDidStopChanging =>
      @updateDiff(editors)
    @editorSubscriptions.add editors.editor2.onDidStopChanging =>
      @updateDiff(editors)
    @editorSubscriptions.add editors.editor1.onDidDestroy =>
      @disable()
    @editorSubscriptions.add editors.editor2.onDidDestroy =>
      @disable()
    @editorSubscriptions.add atom.config.onDidChange 'split-diff', () =>
      @updateDiff(editors)

    # add the bottom UI panel
    if !@footerView?
      @footerView = new FooterView(@_getConfig('ignoreWhitespace'))
      @footerView.createPanel()
    @footerView.show()

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

  # called by both diffPanes and the editor subscription to update the diff
  updateDiff: (editors) ->
    @isEnabled = true

    # if there is a diff being computed in the background, cancel it
    if @process?
      @process.kill()
      @process = null

    isWhitespaceIgnored = @_getConfig('ignoreWhitespace')
    editorPaths = @_createTempFiles(editors)

    # create the loading view if it doesn't exist yet
    if !@loadingView?
      @loadingView = new LoadingView()
      @loadingView.createModal()
    @loadingView.show()

    # --- kick off background process to compute diff ---
    {BufferedNodeProcess} = require 'atom'
    command = path.resolve __dirname, "./compute-diff.js"
    args = [editorPaths.editor1Path, editorPaths.editor2Path, isWhitespaceIgnored]
    theOutput = ''
    stdout = (output) =>
      theOutput = output
      computedDiff = JSON.parse(output)
      @process.kill()
      @process = null
      @loadingView?.hide()
      @_resumeUpdateDiff(editors, computedDiff)
    stderr = (err) =>
      theOutput = err
    exit = (code) =>
      @loadingView?.hide()

      if code != 0
        console.log('BufferedNodeProcess code was ' + code)
        console.log(theOutput)
    @process = new BufferedNodeProcess({command, args, stdout, stderr, exit})
    # --- kick off background process to compute diff ---

  # resumes after the compute diff process returns
  _resumeUpdateDiff: (editors, computedDiff) ->
    @diffView.clearDiff()
    if @syncScroll?
      @syncScroll.dispose()
      @syncScroll = null

    leftHighlightType = 'added'
    rightHighlightType = 'removed'
    if @_getConfig('leftEditorColor') == 'red'
      leftHighlightType = 'removed'
    if @_getConfig('rightEditorColor') == 'green'
      rightHighlightType = 'added'
    @diffView.displayDiff(computedDiff, leftHighlightType, rightHighlightType, @_getConfig('diffWords'), @_getConfig('ignoreWhitespace'))

    @footerView?.setNumDifferences(@diffView.getNumDifferences())

    scrollSyncType = @_getConfig('scrollSyncType')
    if scrollSyncType == 'Vertical + Horizontal'
      @syncScroll = new SyncScroll(editors.editor1, editors.editor2, true)
      @syncScroll.syncPositions()
    else if scrollSyncType == 'Vertical'
      @syncScroll = new SyncScroll(editors.editor1, editors.editor2, false)
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

    BufferExtender = require './buffer-extender'
    buffer1LineEnding = (new BufferExtender(editor1.getBuffer())).getLineEnding()

    if @wasEditor2Created
      # want to scroll a newly created editor to the first editor's position
      atom.views.getView(editor1).focus()
      # set the preferred line ending before inserting text #39
      if buffer1LineEnding == '\n' || buffer1LineEnding == '\r\n'
        @editorSubscriptions.add editor2.onWillInsertText () ->
          editor2.getBuffer().setPreferredLineEnding(buffer1LineEnding)

    @_setupGitRepo(editor1, editor2)

    # unfold all lines so diffs properly align
    editor1.unfoldAll()
    editor2.unfoldAll()

    shouldNotify = !@_getConfig('muteNotifications')
    softWrapMsg = 'Warning: Soft wrap enabled! (Line diffs may not align)'
    if editor1.isSoftWrapped() && shouldNotify
      atom.notifications.addWarning('Split Diff', {detail: softWrapMsg, dismissable: false, icon: 'diff'})
    else if editor2.isSoftWrapped() && shouldNotify
      atom.notifications.addWarning('Split Diff', {detail: softWrapMsg, dismissable: false, icon: 'diff'})

    buffer2LineEnding = (new BufferExtender(editor2.getBuffer())).getLineEnding()
    if buffer2LineEnding != '' && (buffer1LineEnding != buffer2LineEnding) && shouldNotify
      # pop warning if the line endings differ and we haven't done anything about it
      lineEndingMsg = 'Warning: Line endings differ!'
      atom.notifications.addWarning('Split Diff', {detail: lineEndingMsg, dismissable: false, icon: 'diff'})

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
              editor2.selectAll()
              editor2.insertText(gitHeadText)
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


  _getConfig: (config) ->
    atom.config.get("split-diff.#{config}")

  _setConfig: (config, value) ->
    atom.config.set("split-diff.#{config}", value)
