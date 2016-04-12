'use babel'

module.exports = class DiffViewEditor {
  _editor: Object;
  _markers: Array<atom$Marker>;
  _currentSelection: Array<atom$Marker>;

  constructor(editor) {
    this._editor = editor;
    this._markers = [];
    this._currentSelection = [];
    this._oldPlaceholderText = null;
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
    // if there is nothing in the editor, add helper text
    if(this._oldPlaceholderText == null) {
      this._oldPlaceholderText = this._editor.getPlaceholderText();
    }
    this._editor.setPlaceholderText('Paste what you want to diff here!');

    for(var offsetLineNumber of offsetLineNumbers) {
      if(offsetLineNumber != 0) {
        // add block decoration after if adding to lines > 0
        this._addOffsetDecoration(offsetLineNumber-1, lineOffsets[offsetLineNumber], 'after');
      }
    }
  }

  /**
   * Creates markers for line highlights. Adds them to this._markers. Should be
   * called before setLineOffsets since this initializes this._markers.
   *
   * @param changedLines An array of buffer line numbers that should be highlighted.
   * @param type The type of highlight to be applied to the line.
   */
  setLineHighlights(changedLines: Array<number> = [], type: string) {
    this._markers = changedLines.map(lineNumber => this._createLineMarker(lineNumber, type));
  }

  /**
   * Creates a marker and decorates its line and line number.
   *
   * @param lineNumber A buffer line number to be highlighted.
   * @param type The type of highlight to be applied to the line.
   *    Could be a value of: ['insert', 'delete'].
   * @return The newly created marker.
   */
  _createLineMarker(lineNumber: number, type: string): atom$Marker {
    var klass = 'split-diff-' + type;
    var marker = this._editor.markBufferRange([[lineNumber, 0], [lineNumber, 0]], {invalidate: 'never', persistent: false, class: klass})

    this._editor.decorateMarker(marker, {type: 'line-number', class: klass});
    this._editor.decorateMarker(marker, {type: 'line', class: klass});

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

    for(var i=0; i<wordDiff.length; i++) {
      // if there was a change
      // AND one of these is true:
      // if the string is not spaces, highlight
      // OR
      // if the string is spaces and whitespace not ignored, highlight
      if(wordDiff[i].changed
        && (/\S/.test(wordDiff[i].value)
        || (!/\S/.test(wordDiff[i].value) && !isWhitespaceIgnored))){
        var marker = this._editor.markBufferRange([[lineNumber, count], [lineNumber, (count + wordDiff[i].value.length)]], {invalidate: 'never', persistent: false, class: klass})

        this._editor.decorateMarker(marker, {type: 'highlight', class: klass});
        this._markers.push(marker);
      }
      count += wordDiff[i].value.length;
    }
  }

  /**
   * Scrolls the editor to a line.
   *
   * @param lineNumber The line number to scroll to.
   */
  scrollToLine(lineNumber: number): void {
    this._editor.scrollToBufferPosition([lineNumber, 0]);
  }

  /**
   * Destroys all markers added to this editor by split-diff.
   */
  destroyMarkers(): void {
    for(var i=0; i<this._markers.length; i++) {
      this._markers[i].destroy();
    }
    this._markers = [];

    this.deselectAllLines();

    //set the placeholder text back to what it was
    this._editor.setPlaceholderText(this._oldPlaceholderText);
    this._oldPlaceholderText = null;
  }

  /**
   * Not added to this._markers because we want it to persist between updates.
   *
   * @param startLine The line number that the selection starts at.
   * @param endLine The line number that the selection ends at (non-inclusive).
   */
  selectLines(startLine: number, endLine: number): void {
    for(var i=startLine; i<endLine; i++) {
      this._currentSelection.push(this._createLineMarker(i, 'selected'));
    }
  }

  /**
   * Destroy the selection markers.
   */
  deselectAllLines(): void {
    for(var i=0; i<this._currentSelection.length; i++) {
      this._currentSelection[i].destroy();
    }
    this._currentSelection = [];
  }

  /**
   * Enable soft wrap for this editor.
   */
  enableSoftWrap(): void {
    try {
      this._editor.setSoftWrapped(true);
    } catch(e) {
      //console.log('Soft wrap was enabled on a text editor that does not exist.');
    }
  }

  /**
   * Get the text for the line.
   *
   * @param lineNumber The line number to get the text from.
   * @return The text from the specified line.
   */
  getLineText(lineNumber : number): string {
    return this._editor.lineTextForBufferRow(lineNumber);
  }

  /**
   * Checks if the editor contains no text.
   *
   * @return True if the editor is empty.
   */
  isEditorEmpty(): boolean {
    return this._editor.getLineCount() == 1 && this._editor.lineTextForBufferRow(0) == '';
  }
};
