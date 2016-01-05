'use babel'

var {Range}  = require('atom');
var {buildLineRangesWithOffsets} = require('./build-lines-helper');

module.exports = class DiffViewEditor {
  _editor: Object;
  _markers: Array<atom$Marker>;
  _currentSelection: Array<atom$Marker>;
  _lineOffsets: Object;
  _originalBuildScreenLines: () => Object;
  _originalCheckScreenLinesInvariant: () => Object;

  constructor(editor) {
    this._editor = editor;
    this._markers = [];
    this._currentSelection = [];
    this._lineOffsets = {};

    // Ugly Hack to the display buffer to allow fake soft wrapped lines,
    // to create the non-numbered empty space needed between real text buffer lines.
    this._originalBuildScreenLines = this._editor.displayBuffer.buildScreenLines;
    this._originalCheckScreenLinesInvariant = this._editor.displayBuffer.checkScreenLinesInvariant;
    this._editor.displayBuffer.checkScreenLinesInvariant = () => {};
    this._editor.displayBuffer.buildScreenLines = (...args) => this._buildScreenLinesWithOffsets.apply(this, args);
  }

  _buildScreenLinesWithOffsets(startBufferRow: number, endBufferRow: number): LineRangesWithOffsets {
    var {regions, screenLines} = this._originalBuildScreenLines.apply(this._editor.displayBuffer, arguments);
    if (!Object.keys(this._lineOffsets).length) {
      return {regions, screenLines};
    }

    return buildLineRangesWithOffsets(screenLines, this._lineOffsets, startBufferRow, endBufferRow,
      () => {
        var copy = screenLines[0].copy();
        copy.token = [];
        copy.text = '';
        copy.tags = [];
        return copy;
      }
    );
  }

  setLineOffsets(lineOffsets: any): void {
    this._lineOffsets = lineOffsets;
    // When the diff view is editable: upon edits in the new editor, the old editor needs to update its
    // rendering state to show the offset wrapped lines.
    // This isn't a public API, but came from a discussion on the Atom public channel.
    // Needed Atom API: Request a full re-render from an editor.
    this._editor.displayBuffer.updateAllScreenLines();
  }

  removeLineOffsets(): void {
    this._editor.displayBuffer.checkScreenLinesInvariant = this._originalCheckScreenLinesInvariant;
    this._editor.displayBuffer.buildScreenLines = this._originalBuildScreenLines;
    this._editor.displayBuffer.updateAllScreenLines();
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
    var screenPosition = this._editor.screenPositionForBufferPosition({row: lineNumber, column: 0});
    var marker = this._editor.markScreenPosition(screenPosition, {invalidate: 'never', persistent: false, class: klass});

    this._editor.decorateMarker(marker, {type: 'line', class: klass});
    return marker;
  }

  removeLineHighlights(): void {
    this._markers.map(marker => marker.destroy());
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
};
