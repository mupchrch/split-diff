'use babel'

module.exports = class EditorDiffExtender {
  _editor: Object;
  _markers: Array<atom$Marker>;
  _currentSelection: Array<atom$Marker>;

  constructor(editor) {
    this._editor = editor;
    this._markers = [];
    this._currentSelection = null;
    this._oldPlaceholderText = editor.getPlaceholderText();
    editor.setPlaceholderText('Paste what you want to diff here!');
    // add split-diff css selector to editors for keybindings #73
    atom.views.getView(this._editor).classList.add('split-diff');
  }

  /**
   * Creates a decoration for an offset. Adds the marker to this._markers.
   *
   * @param lineNumber The line number to add the block decoration to.
   * @param numberOfLines The number of lines that the block decoration's height will be.
   * @param blockPosition Specifies whether to put the decoration before the line or after.
   */
  _addOffsetDecoration(lineNumber, numberOfLines, blockPosition): void {
    var element = document.createElement('div');
    element.className += 'split-diff-offset';
    // if no text, set height for blank lines
    element.style.minHeight = (numberOfLines * this._editor.getLineHeightInPixels()) + 'px';

    var marker = this._editor.markScreenPosition([lineNumber, 0], {invalidate: 'never', persistent: false});
    this._editor.decorateMarker(marker, {type: 'block', position: blockPosition, item: element});
    this._markers.push(marker);
  }

  /**
   * Adds offsets (blank lines) into the editor.
   *
   * @param lineOffsets An array of offsets (blank lines) to insert into this editor.
   */
  setLineOffsets(lineOffsets: any): void {
    var offsetLineNumbers = Object.keys(lineOffsets).map(lineNumber => parseInt(lineNumber, 10)).sort((x, y) => x - y);

    for (var offsetLineNumber of offsetLineNumbers) {
      if (offsetLineNumber == 0) {
        // add block decoration before if adding to line 0
        this._addOffsetDecoration(offsetLineNumber-1, lineOffsets[offsetLineNumber], 'before');
      } else {
        // add block decoration after if adding to lines > 0
        this._addOffsetDecoration(offsetLineNumber-1, lineOffsets[offsetLineNumber], 'after');
      }
    }
  }

  /**
   * Creates marker for line highlight. Adds it to this._markers.
   *
   * @param startIndex The start index of the line chunk to highlight.
   * @param endIndex The end index of the line chunk to highlight.
   * @param highlightType The type of highlight to be applied to the line.
   */
  highlightLines( startIndex, endIndex, highlightType ) {
    if( startIndex != endIndex ) {
      var highlightClass = 'split-diff-' + highlightType;
      this._markers.push( this._createLineMarker( startIndex, endIndex, highlightClass ) );
    }
  }

  /**
   * Creates a marker and decorates its line and line number.
   *
   * @param startLineNumber A buffer line number to start highlighting at.
   * @param endLineNumber A buffer line number to end highlighting at.
   * @param highlightClass The type of highlight to be applied to the line.
   *    Could be a value of: ['split-diff-insert', 'split-diff-delete',
   *    'split-diff-select'].
   * @return The created line marker.
   */
  _createLineMarker(startLineNumber: number, endLineNumber: number, highlightClass: string): atom$Marker {
    var marker = this._editor.markBufferRange([[startLineNumber, 0], [endLineNumber, 0]], {invalidate: 'never', persistent: false, class: highlightClass})

    this._editor.decorateMarker(marker, {type: 'line-number', class: highlightClass});
    this._editor.decorateMarker(marker, {type: 'line', class: highlightClass});

    return marker;
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
  setWordHighlights(lineNumber: number, wordDiff: Array<any> = [], type: string, isWhitespaceIgnored: boolean): void {
    var klass = 'split-diff-word-' + type;
    var count = 0;

    for (var i=0; i<wordDiff.length; i++) {
      if (wordDiff[i].value) { // fix for #49
        // if there was a change
        // AND one of these is true:
        // if the string is not spaces, highlight
        // OR
        // if the string is spaces and whitespace not ignored, highlight
        if (wordDiff[i].changed
          && (/\S/.test(wordDiff[i].value)
          || (!/\S/.test(wordDiff[i].value) && !isWhitespaceIgnored))) {
          var marker = this._editor.markBufferRange([[lineNumber, count], [lineNumber, (count + wordDiff[i].value.length)]], {invalidate: 'never', persistent: false, class: klass})

          this._editor.decorateMarker(marker, {type: 'highlight', class: klass});
          this._markers.push(marker);
        }
        count += wordDiff[i].value.length;
      }
    }
  }

  /**
   * Destroys all markers added to this editor by split-diff.
   */
  destroyMarkers(): void {
    for (var i=0; i<this._markers.length; i++) {
      this._markers[i].destroy();
    }
    this._markers = [];

    this.deselectAllLines();
  }

  /**
   * Destroys the instance of the EditorDiffExtender and cleans up after itself.
   */
  destroy(): void {
      this.destroyMarkers();
      this._editor.setPlaceholderText(this._oldPlaceholderText);
      // remove split-diff css selector from editors for keybindings #73
      atom.views.getView(this._editor).classList.remove('split-diff')
  }

  /**
   * Not added to this._markers because we want it to persist between updates.
   *
   * @param startLine The line number that the selection starts at.
   * @param endLine The line number that the selection ends at (non-inclusive).
   */
  selectLines(startLine: number, endLine: number): void {
    // don't want to highlight if they are the same (same numbers means chunk is
    // just pointing to a location to copy-to-right/copy-to-left)
    if (startLine < endLine) {
      this._currentSelection = this._createLineMarker(startLine, endLine, 'split-diff-selected');
    }
  }

  /**
   * Destroy the selection markers.
   */
  deselectAllLines(): void {
    if (this._currentSelection) {
      this._currentSelection.destroy();
      this._currentSelection = null;
    }
  }

  /**
   * Used to test whether there is currently an active selection highlight in
   * the editor.
   *
   * @return A boolean signifying whether there is an active selection highlight.
   */
  hasSelection(): boolean {
    if(this._currentSelection) {
        return true;
    }
    return false;
  }

  /**
   * Enable soft wrap for this editor.
   */
  enableSoftWrap(): void {
    try {
      this._editor.setSoftWrapped(true);
    } catch (e) {
      //console.log('Soft wrap was enabled on a text editor that does not exist.');
    }
  }

  /**
   * Removes the text editor without prompting a save.
   */
  cleanUp(): void {
    // if the pane that this editor was in is now empty, we will destroy it
    var editorPane = atom.workspace.paneForItem(this._editor);
    if (typeof editorPane !== 'undefined' && editorPane != null && editorPane.getItems().length == 1) {
      editorPane.destroy();
    } else {
      this._editor.destroy();
    }
  }

  /**
   * Finds cursor-touched line ranges that are marked as different in an editor
   * view.
   *
   * @return The line ranges of diffs that are touched by a cursor.
   */
  getCursorDiffLines(): any {
    var cursorPositions = this._editor.getCursorBufferPositions();
    var touchedLines = [];

    for (var i=0; i<cursorPositions.length; i++) {
      for (var j=0; j<this._markers.length; j++) {
        var markerRange = this._markers[j].getBufferRange();

        if (cursorPositions[i].row >= markerRange.start.row
          && cursorPositions[i].row < markerRange.end.row) {
            touchedLines.push(markerRange);
            break;
        }
      }
    }

    // put the chunks in order so the copy function doesn't mess up
    touchedLines.sort(function(lineA, lineB) {
      return lineA.start.row - lineB.start.row;
    });

    return touchedLines;
  }

  /**
   * Used to get the Text Editor object for this view. Helpful for calling basic
   * Atom Text Editor functions.
   *
   * @return The Text Editor object for this view.
   */
  getEditor(): TextEditor {
    return this._editor;
  }
};
