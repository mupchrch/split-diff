{CompositeDisposable, Directory, File} = require 'atom'
DiffView = require './diff-view'
LoadingView = require './ui/loading-view'
FooterView = require './ui/footer-view'
SyncScroll = require './sync-scroll'
StyleCalculator = require './style-calculator'
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
  wasEditor1SoftWrapped: false
  wasEditor2SoftWrapped: false
  hasGitRepo: false
  docksToReopen: {left: false, right: false, bottom: false}
  process: null
  splitDiffResolves: []
  options: {}

  activate: (state) ->
    @contextForService = this

    styleCalculator = new StyleCalculator(atom.styles, atom.config)
    styleCalculator.startWatching(
        'split-diff-custom-styles',
        ['split-diff.colors.addedColor', 'split-diff.colors.removedColor'],
        (config) ->
          addedColor = config.get('split-diff.colors.addedColor')
          addedColor.alpha = 0.4
          addedWordColor = addedColor
          addedWordColor.alpha = 0.5
          removedColor = config.get('split-diff.colors.removedColor')
          removedColor.alpha = 0.4
          removedWordColor = removedColor
          removedWordColor.alpha = 0.5
          "\n
          .split-diff-added-custom {\n
            \tbackground-color: #{addedColor.toRGBAString()};\n
          }\n
          .split-diff-removed-custom {\n
            \tbackground-color: #{removedColor.toRGBAString()};\n
          }\n
          .split-diff-word-added-custom .region {\n
            \tbackground-color: #{addedWordColor.toRGBAString()};\n
          }\n
          .split-diff-word-removed-custom .region {\n
            \tbackground-color: #{removedWordColor.toRGBAString()};\n
          }\n"
    )

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
      else if @wasEditor1SoftWrapped
        @diffView.restoreEditorSoftWrap(1)
      if @wasEditor2Created
        @diffView.cleanUpEditor(2)
      else if @wasEditor2SoftWrapped
        @diffView.restoreEditorSoftWrap(2)
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

    # auto hide tree view while diffing #82
    hideDocks = @options.hideDocks ? @_getConfig('hideDocks')
    if hideDocks
      if @docksToReopen.left
        atom.workspace.getLeftDock().show()
      if @docksToReopen.right
        atom.workspace.getRightDock().show()
      if @docksToReopen.bottom
        atom.workspace.getBottomDock().show()

    # reset all variables
    @docksToReopen = {left: false, right: false, bottom: false}
    @wasEditor1Created = false
    @wasEditor2Created = false
    @wasEditor1SoftWrapped = false
    @wasEditor2SoftWrapped = false
    @hasGitRepo = false

  # called by "toggle ignore whitespace" command
  toggleIgnoreWhitespace: ->
    # if ignoreWhitespace is not being overridden
    if !(@options.ignoreWhitespace?)
      ignoreWhitespace = @_getConfig('ignoreWhitespace')
      @_setConfig('ignoreWhitespace', !ignoreWhitespace)
      @footerView?.setIgnoreWhitespace(!ignoreWhitespace)

  # called by "Move to next diff" command
  nextDiff: ->
    if @diffView?
      isSyncScrollEnabled = false
      scrollSyncType = @options.scrollSyncType ? @_getConfig('scrollSyncType')
      if scrollSyncType == 'Vertical + Horizontal' || scrollSyncType == 'Vertical'
        isSyncScrollEnabled = true
      selectedIndex = @diffView.nextDiff(isSyncScrollEnabled)
      @footerView?.showSelectionCount( selectedIndex + 1 )

  # called by "Move to previous diff" command
  prevDiff: ->
    if @diffView?
      isSyncScrollEnabled = false
      scrollSyncType = @options.scrollSyncType ? @_getConfig('scrollSyncType')
      if scrollSyncType == 'Vertical + Horizontal' || scrollSyncType == 'Vertical'
        isSyncScrollEnabled = true
      selectedIndex = @diffView.prevDiff(isSyncScrollEnabled)
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
  # editorsPromise is an optional argument of a promise that returns with 2 editors
  # options is an optional argument with optional properties that are used to override user's settings
  diffPanes: (event, editorsPromise, options = {}) ->
    @options = options

    if !editorsPromise
      if event?.currentTarget.classList.contains('tab') || event?.currentTarget.classList.contains('file')
        elemWithPath = event.currentTarget.querySelector('[data-path]')
        params = {}

        if elemWithPath
          params.path = elemWithPath.dataset.path
        else if event.currentTarget.item
          params.editor = event.currentTarget.item.copy() # copy here so still have it if disable closes it #124

        @disable() # make sure we're in a good starting state
        editorsPromise = @_getEditorsForDiffWithActive(params)
      else
        @disable() # make sure we're in a good starting state
        editorsPromise = @_getEditorsForQuickDiff()
    else
      @disable() # make sure we're in a good starting state

    editorsPromise.then ((editors) ->
      if editors == null
        return
      @editorSubscriptions = new CompositeDisposable()
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
      @editorSubscriptions.add editors.editor1.onDidChangeCursorPosition (event) =>
        @diffView.handleCursorChange(event.cursor, event.oldBufferPosition, event.newBufferPosition)
      @editorSubscriptions.add editors.editor2.onDidChangeCursorPosition (event) =>
        @diffView.handleCursorChange(event.cursor, event.oldBufferPosition, event.newBufferPosition)
      @editorSubscriptions.add editors.editor1.onDidAddCursor (cursor) =>
        @diffView.handleCursorChange(cursor, -1, cursor.getBufferPosition())
      @editorSubscriptions.add editors.editor2.onDidAddCursor (cursor) =>
        @diffView.handleCursorChange(cursor, -1, cursor.getBufferPosition())

      # add the bottom UI panel
      if !@footerView?
        ignoreWhitespace = @options.ignoreWhitespace ? @_getConfig('ignoreWhitespace')
        @footerView = new FooterView(ignoreWhitespace, (@options.ignoreWhitespace?))
        @footerView.createPanel()
      @footerView.show()

      # auto hide tree view while diffing #82
      hideDocks = @options.hideDocks ? @_getConfig('hideDocks')
      if hideDocks
        @docksToReopen.left = atom.workspace.getLeftDock().isVisible()
        @docksToReopen.right = atom.workspace.getRightDock().isVisible()
        @docksToReopen.bottom = atom.workspace.getBottomDock().isVisible()
        atom.workspace.getLeftDock().hide()
        atom.workspace.getRightDock().hide()
        atom.workspace.getBottomDock().hide()

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

    ignoreWhitespace = @options.ignoreWhitespace ? @_getConfig('ignoreWhitespace')
    editorPaths = @_createTempFiles(editors)

    # create the loading view if it doesn't exist yet
    if !@loadingView?
      @loadingView = new LoadingView()
      @loadingView.createModal()
    @loadingView.show()

    # --- kick off background process to compute diff ---
    {BufferedNodeProcess} = require 'atom'
    command = path.resolve __dirname, "./compute-diff.js"
    args = [editorPaths.editor1Path, editorPaths.editor2Path, ignoreWhitespace]
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
    return unless @diffView?

    @diffView.clearDiff()
    if @syncScroll?
      @syncScroll.dispose()
      @syncScroll = null

    # grab the settings for the diff
    addedColorSide = @options.addedColorSide ? @_getConfig('colors.addedColorSide')
    diffWords = @options.diffWords ? @_getConfig('diffWords')
    ignoreWhitespace = @options.ignoreWhitespace ? @_getConfig('ignoreWhitespace')
    overrideThemeColors = @options.overrideThemeColors ? @_getConfig('colors.overrideThemeColors')

    @diffView.displayDiff(computedDiff, addedColorSide, diffWords, ignoreWhitespace, overrideThemeColors)

    # give the marker layers to those registered with the service
    while @splitDiffResolves?.length
      @splitDiffResolves.pop()(@diffView.getMarkerLayers())

    @footerView?.setNumDifferences(@diffView.getNumDifferences())

    scrollSyncType = @options.scrollSyncType ? @_getConfig('scrollSyncType')
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
    panes = atom.workspace.getCenter().getPanes()
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
      editor1 = atom.workspace.buildTextEditor({autoHeight: false})
      @wasEditor1Created = true
      # add first editor to the first pane
      panes[0].addItem(editor1)
      panes[0].activateItem(editor1)
    if editor2 == null
      editor2 = atom.workspace.buildTextEditor({autoHeight: false})
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
  _getEditorsForDiffWithActive: (params) ->
    filePath = params.path
    editorWithoutPath = params.editor
    activeEditor = atom.workspace.getCenter().getActiveTextEditor()

    if activeEditor?
      editor1 = activeEditor
      @wasEditor2Created = true
      panes = atom.workspace.getCenter().getPanes()
      # get index of pane following active editor pane
      rightPaneIndex = panes.indexOf(atom.workspace.paneForItem(editor1)) + 1
      # pane is created if there is not one to the right of the active editor
      rightPane = panes[rightPaneIndex] || atom.workspace.paneForItem(editor1).splitRight()

      if params.path
        filePath = params.path
        if editor1.getPath() == filePath
          # if diffing with itself, set filePath to null so an empty editor is
          # opened, which will cause a git diff
          filePath = null
        editor2Promise = atom.workspace.openURIInPane(filePath, rightPane)

        return editor2Promise.then (editor2) ->
          return {editor1: editor1, editor2: editor2}
      else if editorWithoutPath
        editor2 = editorWithoutPath.copy()
        rightPane.addItem(editor2)

        return Promise.resolve({editor1: editor1, editor2: editor2})
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

    muteNotifications = @options.muteNotifications ? @_getConfig('muteNotifications')
    turnOffSoftWrap = @options.turnOffSoftWrap ? @_getConfig('turnOffSoftWrap')
    if turnOffSoftWrap
      shouldNotify = false
      if editor1.isSoftWrapped()
        @wasEditor1SoftWrapped = true
        editor1.setSoftWrapped(false)
        shouldNotify = true
      if editor2.isSoftWrapped()
        @wasEditor2SoftWrapped = true
        editor2.setSoftWrapped(false)
        shouldNotify = true
      if shouldNotify && !muteNotifications
        softWrapMsg = 'Soft wrap automatically disabled so lines remain in sync.'
        atom.notifications.addWarning('Split Diff', {detail: softWrapMsg, dismissable: false, icon: 'diff'})
    else if !muteNotifications && (editor1.isSoftWrapped() || editor2.isSoftWrapped())
      softWrapMsg = 'Warning: Soft wrap enabled! Lines may not align.\n(Try "Turn Off Soft Wrap" setting)'
      atom.notifications.addWarning('Split Diff', {detail: softWrapMsg, dismissable: false, icon: 'diff'})

    buffer2LineEnding = (new BufferExtender(editor2.getBuffer())).getLineEnding()
    if buffer2LineEnding != '' && (buffer1LineEnding != buffer2LineEnding) && editor1.getLineCount() != 1 && editor2.getLineCount() != 1 && !muteNotifications
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
          if projectRepo?
            projectRepo = projectRepo.getRepo(editor1Path) # fix repo for submodules #112
            relativeEditor1Path = projectRepo.relativize(editor1Path)
            gitHeadText = projectRepo.getHeadBlob(relativeEditor1Path)
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


  # --- SERVICE API ---
  getMarkerLayers: () ->
    new Promise ((resolve, reject) ->
      @splitDiffResolves.push(resolve)
    ).bind(this)

  diffEditors: (editor1, editor2, options) ->
    @diffPanes(null, Promise.resolve({editor1: editor1, editor2: editor2}), options)

  provideSplitDiff: ->
    getMarkerLayers: @getMarkerLayers.bind(@contextForService)
    diffEditors: @diffEditors.bind(@contextForService)
    disable: @disable.bind(@contextForService)
