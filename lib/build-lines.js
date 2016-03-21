'use babel'

var {Range}  = require('atom');

module.exports = class DiffViewEditor {
  _editor: Object;
  _markers: Array<atom$Marker>;
  _currentSelection: Array<atom$Marker>;
  _originalBuildScreenLines: () => Object;
  _originalCheckScreenLinesInvariant: () => Object;

  constructor(editor) {
    this._editor = editor;
    this._markers = [];
    this._currentSelection = [];
  }

  setLineOffsets(lineOffsets: any): void {
    var offsetLineNumbers = Object.keys(lineOffsets).map(lineNumber => parseInt(lineNumber, 10)).sort((x, y) => x - y);

    for(var offsetLineNumber of offsetLineNumbers) {
      var numberOfBlankLines = lineOffsets[offsetLineNumber];
      var element = document.createElement('div');
      element.style.minHeight = (numberOfBlankLines * this._editor.getLineHeightInPixels()) + 'px';
      element.className += 'split-diff-offset';

      if(offsetLineNumber == 0) {
        var marker = this._editor.markScreenPosition([offsetLineNumber, 0]);
        this._editor.decorateMarker(marker, {type: 'block', position: 'before', item: element});
        this._markers.push(marker);
      } else {
        var marker = this._editor.markScreenPosition([offsetLineNumber-1, 0]);
        this._editor.decorateMarker(marker, {type: 'block', position: 'after', item: element});
        this._markers.push(marker);
      }
    }
  }

  /**
   * @param addedLines An array of buffer line numbers that should be highlighted as added.
   * @param removedLines An array of buffer line numbers that should be highlighted as removed.
   */
  setLineHighlights(addedLines: Array<number> = [], removedLines: Array<number> = []) {
    this._markers = addedLines.map(lineNumber => this._createLineMarker(lineNumber, 'added'))
        .concat(removedLines.map(lineNumber => this._createLineMarker(lineNumber, 'removed')));
  }

  /**
   * @param lineNumber A buffer line number to be highlighted.
   * @param type The type of highlight to be applied to the line.
   *    Could be a value of: ['insert', 'delete'].
   */
  _createLineMarker(lineNumber: number, type: string): atom$Marker {
    var klass = 'split-diff-' + type;
    var marker = this._editor.markBufferRange([[lineNumber, 0], [lineNumber, 0]], {invalidate: 'never', persistent: false, class: klass})

    this._editor.decorateMarker(marker, {type: 'line-number', class: klass});
    this._editor.decorateMarker(marker, {type: 'line', class: klass});

    return marker;
  }

  setCharHighlights(lineNumber: number, parseForRemovedChars: CharDiff, parseForAddedChars: CharDiff) {
    if(parseForRemovedChars) {
      var klass = 'split-diff-char-removed';
      var count = 0;

      for(var i=0; i<parseForRemovedChars.length; i++) {
        if(parseForRemovedChars[i].removed) {
          var marker = this._editor.markBufferRange([[lineNumber, count], [lineNumber, (count + parseForRemovedChars[i].count)]], {invalidate: 'never', persistent: false, class: klass})

          this._editor.decorateMarker(marker, {type: 'highlight', class: klass});
          this._markers.push(marker);
        }

        count += parseForRemovedChars[i].count;
      }
    }

    if(parseForAddedChars) {
      var klass = 'split-diff-char-added';
      var count = 0;

      for(var i=0; i<parseForAddedChars.length; i++) {
        if(parseForAddedChars[i].added) {
          var marker = this._editor.markBufferRange([[lineNumber, count], [lineNumber, (count + parseForAddedChars[i].count)]], {invalidate: 'never', persistent: false, class: klass})

          this._editor.decorateMarker(marker, {type: 'highlight', class: klass});
          this._markers.push(marker);
        }

        count += parseForAddedChars[i].count;
      }
    }
  }

  scrollToTop(): void {
    this._editor.scrollToTop();
  }

  scrollToLine(lineNumber: number): void {
    this._editor.scrollToBufferPosition([lineNumber, 0]);
  }

  destroyMarkers(): void {
    for(var i=0; i<this._markers.length; i++) {
      this._markers[i].destroy();
    }
    this._markers = [];

    this.deselectAllLines();
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

  deselectAllLines(): void {
    for(var i=0; i<this._currentSelection.length; i++) {
      this._currentSelection[i].destroy();
    }
    this._currentSelection = [];
  }

  enableSoftWrap(): void {
    this._editor.setSoftWrapped(true);
  }

  getLineText(lineNumber : number): string {
    return this._editor.lineTextForBufferRow(lineNumber);
  }
};
