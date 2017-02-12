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

    @subscriptions.add atom.commands.add 'atom-workspace, .tree-view .selected, .tab.texteditor',
      'split-diff:enable': (e) =>
        @diffPanes(e)
        e.stopPropagation()
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
  toggle: () ->
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
      @footerView?.showSelectionCount( selectedIndex + 1 )

  # called by "Move to previous diff" command
  prevDiff: ->
    if @diffView?
      selectedIndex = @diffView.prevDiff()
      @footerView?.showSelectionCount( selectedIndex + 1 )

  # called by "Copy to right" command
  copyToRight: ->
    if @diffView?
      @diffView.copyToRight()
      @footerView?.hideSelectionCount()

  # called by "Copy to left" command
  copyToLeft: ->
    if @diffView?
      @diffView.copyToLeft()
      @footerView?.hideSelectionCount()

  # called by the commands enable/toggle to do initial diff
  # sets up subscriptions for auto diff and disabling when a pane is destroyed
  # event is an optional argument of a file path to diff with current
  diffPanes: (event) ->
    # in case enable was called again
    @disable()

    @editorSubscriptions = new CompositeDisposable()

    if event?.currentTarget.classList.contains('tab')
      filePath = event.currentTarget.path
      editorsPromise = @_getEditorsForDiffWithActive(filePath)
    else if event?.currentTarget.classList.contains('list-item') && event?.currentTarget.classList.contains('file')
      filePath = event.currentTarget.getPath()
      editorsPromise = @_getEditorsForDiffWithActive(filePath)
    else
      editorsPromise = @_getEditorsForQuickDiff()

    editorsPromise.then ((editors) ->
      if editors == null
        return
      @_setupVisibleEditors(editors.editor1, editors.editor2)
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
      ).bind(this) # make sure the scope is correct

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

  # Gets the first two visible editors found or creates them as needed.
  # Returns a Promise which yields a value of {editor1: TextEditor, editor2: TextEditor}
  _getEditorsForQuickDiff: () ->
    editor1 = null
    editor2 = null

    # try to find the first two editors
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
      # add first editor to the first pane
      panes[0].addItem(editor1)
      panes[0].activateItem(editor1)
    if editor2 == null
      editor2 = atom.workspace.buildTextEditor()
      @wasEditor2Created = true
      editor2.setGrammar(editor1.getGrammar())
      rightPaneIndex = panes.indexOf(atom.workspace.paneForItem(editor1)) + 1
      if panes[rightPaneIndex]
        # add second editor to existing pane to the right of first editor
        panes[rightPaneIndex].addItem(editor2)
        panes[rightPaneIndex].activateItem(editor2)
      else
        # no existing pane so split right
        atom.workspace.paneForItem(editor1).splitRight({items: [editor2]})

    return Promise.resolve({editor1: editor1, editor2: editor2})

  # Gets the active editor and opens the specified file to the right of it
  # Returns a Promise which yields a value of {editor1: TextEditor, editor2: TextEditor}
  _getEditorsForDiffWithActive: (filePath) ->
    activeEditor = atom.workspace.getActiveTextEditor()
    if activeEditor?
      editor1 = activeEditor
      @wasEditor2Created = true
      panes = atom.workspace.getPanes()
      # get index of pane following active editor pane
      rightPaneIndex = panes.indexOf(atom.workspace.paneForItem(editor1)) + 1
      # pane is created if there is not one to the right of the active editor
      rightPane = panes[rightPaneIndex] || atom.workspace.paneForItem(editor1).splitRight()
      if editor1.getPath() == filePath
        # if diffing with itself, set filePath to null so an empty editor is
        # opened, which will cause a git diff
        filePath = null
      editor2Promise = atom.workspace.openURIInPane(filePath, rightPane)

      return editor2Promise.then (editor2) ->
        return {editor1: editor1, editor2: editor2}
    else
      noActiveEditorMsg = 'No active file found! (Try focusing a text editor)'
      atom.notifications.addWarning('Split Diff', {detail: noActiveEditorMsg, dismissable: false, icon: 'diff'})
      return Promise.resolve(null)

    return Promise.resolve(null)

  _setupVisibleEditors: (editor1, editor2) ->
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
    if buffer2LineEnding != '' && (buffer1LineEnding != buffer2LineEnding) && editor1.getLineCount() != 1 && editor2.getLineCount() != 1 && shouldNotify
      # pop warning if the line endings differ and we haven't done anything about it
      lineEndingMsg = 'Warning: Line endings differ!'
      atom.notifications.addWarning('Split Diff', {detail: lineEndingMsg, dismissable: false, icon: 'diff'})

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
