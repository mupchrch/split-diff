{CompositeDisposable} = require 'atom'
{$} = require 'space-pen'
DiffViewEditor = require './build-lines'
SyncScroll = require './sync-scroll'


module.exports = SplitDiff =
  subscriptions: null
  JsDiff: require 'diff'
  SplitDiffCompute: require './split-diff-compute'
  isEnabled: false
  diffViewEditor1: null
  diffViewEditor2: null

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that finds visible text editors
    @subscriptions.add atom.commands.add 'atom-workspace',
      'split-diff:diffPanes': => @turnOn()
      'split-diff:disable': => @turnOff()

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->
    #splitDiffViewState: @splitDiffView.serialize()

  toggle: ->
    if @isEnabled #turn off
      @turnOff()
    else #turn on
      @turnOn()

  turnOn: ->
    if @isEnabled
      @turnOff()
      
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

    if editor1 == null || editor2 == null
      atom.notifications.addInfo('Split Diff', {detail: 'You must have two panes open.'})
      return

    computedDiff = @SplitDiffCompute.computeDiff(editor1.getText(), editor2.getText())
    console.log computedDiff

    @displayDiff(editor1, editor2, computedDiff)

    @syncScroll = new SyncScroll(editor1, editor2)

    @isEnabled = true
    console.log 'split-diff enabled'

  turnOff: ->
    @diffViewEditor1.removeLineOffsets()
    @diffViewEditor2.removeLineOffsets()

    @diffViewEditor1.removeLineHighlights()
    @diffViewEditor2.removeLineHighlights()

    @syncScroll.dispose()
    @syncScroll = null

    @diffViewEditor1 = null
    @diffViewEditor2 = null
    @isEnabled = false
    console.log 'split-diff disabled'

  displayDiff: (editor1, editor2, computedDiff)->
    @diffViewEditor1 = new DiffViewEditor(editor1)
    @diffViewEditor2 = new DiffViewEditor(editor2)

    @diffViewEditor1.setLineOffsets(computedDiff.oldLineOffsets)
    @diffViewEditor2.setLineOffsets(computedDiff.newLineOffsets)

    @diffViewEditor1.setLineHighlights(undefined, computedDiff.removedLines)
    @diffViewEditor2.setLineHighlights(computedDiff.addedLines, undefined)

    @diffViewEditor1.scrollToTop()
    @diffViewEditor2.scrollToTop()
