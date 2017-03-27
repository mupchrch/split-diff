'use babel'

module.exports = class EditorDiffExtender {

  constructor(editor) {
    this._editor = editor;
    this._lineMarkerLayer = this._editor.addMarkerLayer();
    this._miscMarkers = [];
    this._selectionMarkerLayer = this._editor.addMarkerLayer();
    this._oldPlaceholderText = editor.getPlaceholderText();
    editor.setPlaceholderText('Paste what you want to diff here!');
    // add split-diff css selector to editors for keybindings #73
    atom.views.getView(this._editor).classList.add('split-diff');
  }

  /**
   * Adds offsets (blank lines) into the editor.
   *
   * @param lineOffsets An array of offsets (blank lines) to insert into this editor.
   */
  setLineOffsets(lineOffsets) {
    var offsetLineNumbers = Object.keys(lineOffsets).map(lineNumber => parseInt(lineNumber, 10)).sort((x, y) => x - y);

    for(var offsetLineNumber of offsetLineNumbers) {
      if(offsetLineNumber == 0) {
        // add block decoration before if adding to line 0
        this._addOffsetDecoration(offsetLineNumber-1, lineOffsets[offsetLineNumber], 'before');
      } else {
        // add block decoration after if adding to lines > 0
        this._addOffsetDecoration(offsetLineNumber-1, lineOffsets[offsetLineNumber], 'after');
      }
    }
  }

  /**
   * Creates marker for line highlight.
   *
   * @param startIndex The start index of the line chunk to highlight.
   * @param endIndex The end index of the line chunk to highlight.
   * @param highlightType The type of highlight to be applied to the line.
   */
  highlightLines(startIndex, endIndex, highlightType) {
    if(startIndex != endIndex) {
      var highlightClass = 'split-diff-' + highlightType;
      this._createLineMarker(this._lineMarkerLayer, startIndex, endIndex, highlightClass);
    }
  }

  /**
   * The line marker layer holds all added/removed line markers.
   *
   * @return The line marker layer.
   */
  getLineMarkerLayer() {
    return this._lineMarkerLayer;
  }

  /**
   * The selection marker layer holds all line highlight selection markers.
   *
   * @return The selection marker layer.
   */
  getSelectionMarkerLayer() {
    return this._selectionMarkerLayer;
  }

  /**
   * Highlights words in a given line.
   *
   * @param lineNumber The line number to highlight words on.
   * @param wordDiff An array of objects which look like...
   *    added: boolean (not used)
   *    count: number (not used)
   *    removed: boolean (not used)
   *    value: string
   *    changed: boolean
   * @param type The type of highlight to be applied to the words.
   */
  setWordHighlights(lineNumber, wordDiff = [], type, isWhitespaceIgnored) {
    var klass = 'split-diff-word-' + type;
    var count = 0;

    for(var i=0; i<wordDiff.length; i++) {
      if(wordDiff[i].value) { // fix for #49
        // if there was a change
        // AND one of these is true:
        // if the string is not spaces, highlight
        // OR
        // if the string is spaces and whitespace not ignored, highlight
        if(wordDiff[i].changed
          && (/\S/.test(wordDiff[i].value)
          || (!/\S/.test(wordDiff[i].value) && !isWhitespaceIgnored))) {
          var marker = this._editor.markBufferRange([[lineNumber, count], [lineNumber, (count + wordDiff[i].value.length)]], {invalidate: 'never'})
          this._editor.decorateMarker(marker, {type: 'highlight', class: klass});
          this._miscMarkers.push(marker);
        }
        count += wordDiff[i].value.length;
      }
    }
  }

  /**
   * Destroys all markers added to this editor by split-diff.
   */
  destroyMarkers() {
    this._lineMarkerLayer.clear();

    this._miscMarkers.forEach(function(marker) {
      marker.destroy();
    });
    this._miscMarkers = [];

    this._selectionMarkerLayer.clear();
  }

  /**
   * Destroys the instance of the EditorDiffExtender and cleans up after itself.
   */
  destroy() {
    this.destroyMarkers();
    this._lineMarkerLayer.destroy();
    this._editor.setPlaceholderText(this._oldPlaceholderText);
    // remove split-diff css selector from editors for keybindings #73
    atom.views.getView(this._editor).classList.remove('split-diff');
  }

  /**
   * Selects lines.
   *
   * @param startLine The line number that the selection starts at.
   * @param endLine The line number that the selection ends at (non-inclusive).
   */
  selectLines(startLine, endLine) {
    // don't want to highlight if they are the same (same numbers means chunk is
    // just pointing to a location to copy-to-right/copy-to-left)
    if(startLine < endLine) {
      var selectionMarker = this._selectionMarkerLayer.findMarkers({
        startBufferRow: startLine,
        endBufferRow: endLine
      })[0];
      if(!selectionMarker) {
        this._createLineMarker(this._selectionMarkerLayer, startLine, endLine, 'split-diff-selected');
      }
    }
  }

  deselectLines(startLine, endLine) {
    var selectionMarker = this._selectionMarkerLayer.findMarkers({
      startBufferRow: startLine,
      endBufferRow: endLine
    })[0];
    if(selectionMarker) {
      selectionMarker.destroy();
    }
  }

  /**
   * Destroy the selection markers.
   */
  deselectAllLines() {
    this._selectionMarkerLayer.clear();
  }

  /**
   * Used to test whether there is currently an active selection highlight in
   * the editor.
   *
   * @return A boolean signifying whether there is an active selection highlight.
   */
  hasSelection() {
    if(this._selectionMarkerLayer.getMarkerCount() > 0) {
      return true;
    }
    return false;
  }

  /**
   * Enable soft wrap for this editor.
   */
  enableSoftWrap() {
    try {
      this._editor.setSoftWrapped(true);
    } catch (e) {
      //console.log('Soft wrap was enabled on a text editor that does not exist.');
    }
  }

  /**
   * Removes the text editor without prompting a save.
   */
  cleanUp() {
    // if the pane that this editor was in is now empty, we will destroy it
    var editorPane = atom.workspace.paneForItem(this._editor);
    if(typeof editorPane !== 'undefined' && editorPane != null && editorPane.getItems().length == 1) {
      editorPane.destroy();
    } else {
      this._editor.destroy();
    }
  }

  /**
   * Used to get the Text Editor object for this view. Helpful for calling basic
   * Atom Text Editor functions.
   *
   * @return The Text Editor object for this view.
   */
  getEditor() {
    return this._editor;
  }

  // ----------------------------------------------------------------------- //
  // --------------------------- PRIVATE METHODS --------------------------- //
  // ----------------------------------------------------------------------- //

  /**
   * Creates a marker and decorates its line and line number.
   *
   * @param markerLayer The marker layer to put the marker in.
   * @param startLineNumber A buffer line number to start highlighting at.
   * @param endLineNumber A buffer line number to end highlighting at.
   * @param highlightClass The type of highlight to be applied to the line.
   *    Could be a value of: ['split-diff-insert', 'split-diff-delete',
   *    'split-diff-select'].
   * @return The created line marker.
   */
  _createLineMarker(markerLayer, startLineNumber, endLineNumber, highlightClass) {
    var marker = markerLayer.markBufferRange([[startLineNumber, 0], [endLineNumber, 0]], {invalidate: 'never'})

    this._editor.decorateMarker(marker, {type: 'line-number', class: highlightClass});
    this._editor.decorateMarker(marker, {type: 'line', class: highlightClass});

    return marker;
  }

  /**
   * Creates a decoration for an offset.
   *
   * @param lineNumber The line number to add the block decoration to.
   * @param numberOfLines The number of lines that the block decoration's height will be.
   * @param blockPosition Specifies whether to put the decoration before the line or after.
   */
  _addOffsetDecoration(lineNumber, numberOfLines, blockPosition) {
    var element = document.createElement('div');
    element.className += 'split-diff-offset';
    // if no text, set height for blank lines
    element.style.minHeight = (numberOfLines * this._editor.getLineHeightInPixels()) + 'px';

    var marker = this._editor.markScreenPosition([lineNumber, 0], {invalidate: 'never'});
    this._editor.decorateMarker(marker, {type: 'block', position: blockPosition, item: element});
    this._miscMarkers.push(marker);
  }
};
