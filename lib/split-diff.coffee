{CompositeDisposable} = require 'atom'
{$} = require 'space-pen'
DiffViewEditor = require './build-lines'
SyncScroll = require './sync-scroll'


module.exports = SplitDiff =
  subscriptions: null
  isEnabled: false
  diffViewEditor1: null
  diffViewEditor2: null
  editorSubscriptions: null

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable
    @editorSubscriptions = new CompositeDisposable

    # Register command that finds visible text editors
    @subscriptions.add atom.commands.add 'atom-workspace',
      'split-diff:diffPanes': => @diffPanes()
      'split-diff:disable': => @clearDiff()

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->
    #splitDiffViewState: @splitDiffView.serialize()

  toggle: ->
    if @isEnabled #turn off
      @turnOff()
    else #turn on
      @turnOn()

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

    editors =
      editor1: editor1
      editor2: editor2
    return editors

  diffPanes: ->
    editors = @getVisibleEditors()

    if editors.editor1 == null || editors.editor2 == null
      atom.notifications.addInfo('Split Diff', {detail: 'You must have two panes open.'})
      return

    @editorSubscriptions.add editors.editor1.onDidStopChanging =>
      @updateDiff(editors)
    @editorSubscriptions.add editors.editor2.onDidStopChanging =>
      @updateDiff(editors)
    @editorSubscriptions.add editors.editor1.onDidDestroy =>
      console.log('dest e1')
      @editorSubscriptions.dispose()
      @clearDiff()
    @editorSubscriptions.add editors.editor2.onDidDestroy =>
      console.log('dest e2')
      @editorSubscriptions.dispose()
      @clearDiff()

    @updateDiff(editors)

  updateDiff: (editors) ->
    if @isEnabled
      @clearDiff()

    SplitDiffCompute = require './split-diff-compute'
    computedDiff = SplitDiffCompute.computeDiff(editors.editor1.getText(), editors.editor2.getText())
    console.log computedDiff

    @displayDiff(editors, computedDiff)

    @syncScroll = new SyncScroll(editors.editor1, editors.editor2)

    @isEnabled = true
    console.log 'split-diff enabled'

  clearDiff: ->
    @diffViewEditor1.removeLineOffsets()
    @diffViewEditor1.removeLineHighlights()

    @diffViewEditor2.removeLineOffsets()
    @diffViewEditor2.removeLineHighlights()

    @syncScroll.dispose()
    @syncScroll = null

    @diffViewEditor1 = null
    @diffViewEditor2 = null
    @isEnabled = false
    console.log 'split-diff disabled'

  displayDiff: (editors, computedDiff) ->
    @diffViewEditor1 = new DiffViewEditor(editors.editor1)
    @diffViewEditor2 = new DiffViewEditor(editors.editor2)

    @diffViewEditor1.setLineOffsets(computedDiff.oldLineOffsets)
    @diffViewEditor2.setLineOffsets(computedDiff.newLineOffsets)

    @diffViewEditor1.setLineHighlights(undefined, computedDiff.removedLines)
    @diffViewEditor2.setLineHighlights(computedDiff.addedLines, undefined)

    #@diffViewEditor1.scrollToTop()
    #@diffViewEditor2.scrollToTop()
