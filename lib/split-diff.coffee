#SplitDiffView = require './split-diff-view'
{CompositeDisposable} = require 'atom'
{$} = require 'space-pen'


module.exports = SplitDiff =
  #splitDiffView: null
  #modalPanel: null
  subscriptions: null

  activate: (state) ->
    #atom.workspace.observeTextEditors (editor) => console.log editor

    #@splitDiffView = new SplitDiffView(state.splitDiffViewState)
    #@modalPanel = atom.workspace.addModalPanel(item: @splitDiffView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that finds visible text editors
    @subscriptions.add atom.commands.add 'atom-workspace', 'split-diff:getEditors': => @getEditors()

  deactivate: ->
    #@modalPanel.destroy()
    @subscriptions.dispose()
    #@splitDiffView.destroy()

  serialize: ->
    #splitDiffViewState: @splitDiffView.serialize()

  getEditors: ->
    atom.workspace.observeTextEditors (editor) =>
      editorView = atom.views.getView(editor)
      $editorView = $(editorView)
      if $editorView.is ':visible'
        console.log $editorView
