{CompositeDisposable} = require 'atom'
{$} = require 'space-pen'


module.exports = SplitDiff =
  subscriptions: null
  JsDiff: require 'diff'
  BuildLines: require './build-lines.js'
  markers: []
  isEnabled: false

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that finds visible text editors
    @subscriptions.add atom.commands.add 'atom-workspace', 'split-diff:toggle': => @toggle()

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->
    #splitDiffViewState: @splitDiffView.serialize()

  toggle: ->
    #TODO(mike): create functions for turn on/off instead of having code in here
    if @isEnabled #turn off
      @removeLineHighlights()
      @isEnabled = false
      console.log 'split-diff disabled'
    else #turn on
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

      #TODO(mike): add error checking on editors here

      diff = @diffLines(editor1, editor2)
      @addLineHighlights(editor1, editor2, diff)
      @isEnabled = true
      console.log 'split-diff enabled'

  diffLines: (editor1, editor2)->
    diff = @JsDiff.diffLines(editor1.getText(), editor2.getText(), true, true);
    return diff

  addLineHighlights: (editor1, editor2, diff) ->
    editor1LineNum = 0
    editor2LineNum = 0

    for changeObject in diff
      #console.log changeObject
      if changeObject.added
        console.log 'green from ' + (editor1LineNum+1) + ' thru ' + (editor1LineNum+changeObject.count)
        marker = editor2.markBufferRange([[editor1LineNum, 0], [editor1LineNum + changeObject.count, 0]], invalidate: 'never')
        editor2.decorateMarker(marker, type: 'line', class: 'line-green')
        @markers.push(marker)
        editor1LineNum = editor1LineNum + changeObject.count
      else if changeObject.removed
        console.log 'red from ' + (editor2LineNum+1) + ' thru ' + (editor2LineNum+changeObject.count)
        marker = editor1.markBufferRange([[editor2LineNum, 0], [editor2LineNum + changeObject.count, 0]], invalidate: 'never')
        editor1.decorateMarker(marker, type: 'line', class: 'line-red')
        @markers.push(marker)
        editor2LineNum = editor2LineNum + changeObject.count
      else
        editor1LineNum = editor1LineNum + changeObject.count
        editor2LineNum = editor2LineNum + changeObject.count

  removeLineHighlights: ->
    marker.destroy() for marker in @markers
    @markers = []

#eventually i'll need this:
#  // Ugly Hack to the display buffer to allow fake soft wrapped lines,
#  // to create the non-numbered empty space needed between real text buffer lines.
#  this._originalBuildScreenLines = this._editor.displayBuffer.buildScreenLines;
#  this._editor.displayBuffer.checkScreenLinesInvariant = function () {};
#  this._editor.displayBuffer.buildScreenLines = function () {
#    for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
#      args[_key] = arguments[_key];
#    }
#
#    return _this._buildScreenLinesWithOffsets.apply(_this, args);
#  };
