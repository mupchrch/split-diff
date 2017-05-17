'use babel'

import EditorDiffExtender from './editor-diff-extender';
import ComputeWordDiff from './compute-word-diff';


module.exports = class DiffView {
  /*
   * @param editors Array of editors being diffed.
   */
  constructor(editors) {
    this._editorDiffExtender1 = new EditorDiffExtender(editors.editor1);
    this._editorDiffExtender2 = new EditorDiffExtender(editors.editor2);
    this._chunks = [];
    this._isSelectionActive = false;
    this._selectedChunkIndex = 0;
    this._COPY_HELP_MESSAGE = 'No differences selected.';
    this._markerLayers = {};
  }

  /**
   * Adds highlighting to the editors to show the diff.
   *
   * @param diff The diff to highlight.
   * @param addedColorSide The side that the added highlights should be applied to. Either 'left' or 'right'.
   * @param isWordDiffEnabled Whether differences between words per line should be highlighted.
   * @param isWhitespaceIgnored Whether whitespace should be ignored.
   * @param useCustomStyle Whether to use the user's customized highlight colors.
   */
  displayDiff(diff, addedColorSide, isWordDiffEnabled, isWhitespaceIgnored, useCustomStyle) {
    this._chunks = diff.chunks || [];

    var leftHighlightType = 'added';
    var rightHighlightType = 'removed';
    if(addedColorSide == 'right') {
      leftHighlightType = 'removed';
      rightHighlightType = 'added';
    }
    if(useCustomStyle) {
      leftHighlightType += '-custom';
      rightHighlightType += '-custom';
    }

    // make the last chunk equal size on both screens so the editors retain sync scroll #58
    if(this.getNumDifferences() > 0) {
      var lastChunk = this._chunks[this._chunks.length - 1];
      var oldChunkRange = lastChunk.oldLineEnd - lastChunk.oldLineStart;
      var newChunkRange = lastChunk.newLineEnd - lastChunk.newLineStart;
      if(oldChunkRange > newChunkRange) {
        // make the offset as large as needed to make the chunk the same size in both editors
        diff.newLineOffsets[lastChunk.newLineStart + newChunkRange] = oldChunkRange - newChunkRange;
      } else if(newChunkRange > oldChunkRange) {
        // make the offset as large as needed to make the chunk the same size in both editors
        diff.oldLineOffsets[lastChunk.oldLineStart + oldChunkRange] = newChunkRange - oldChunkRange;
      }
    }

    for(var chunk of this._chunks) {
      this._editorDiffExtender1.highlightLines(chunk.oldLineStart, chunk.oldLineEnd, leftHighlightType);
      this._editorDiffExtender2.highlightLines(chunk.newLineStart, chunk.newLineEnd, rightHighlightType);

      if(isWordDiffEnabled) {
        this._highlightWordsInChunk(chunk, leftHighlightType, rightHighlightType, isWhitespaceIgnored);
      }
    }

    this._editorDiffExtender1.setLineOffsets(diff.oldLineOffsets);
    this._editorDiffExtender2.setLineOffsets(diff.newLineOffsets);

    this._markerLayers = {
      editor1: {
        id: this._editorDiffExtender1.getEditor().id,
        lineMarkerLayer: this._editorDiffExtender1.getLineMarkerLayer(),
        highlightType: leftHighlightType,
        selectionMarkerLayer: this._editorDiffExtender1.getSelectionMarkerLayer()
      },
      editor2: {
        id: this._editorDiffExtender2.getEditor().id,
        lineMarkerLayer: this._editorDiffExtender2.getLineMarkerLayer(),
        highlightType: rightHighlightType,
        selectionMarkerLayer: this._editorDiffExtender2.getSelectionMarkerLayer()
      }
    }
  }

  /**
   * Clears the diff highlighting and offsets from the editors.
   */
  clearDiff() {
    this._editorDiffExtender1.destroyMarkers();
    this._editorDiffExtender2.destroyMarkers();
  }

  /**
   * Called to move the current selection highlight to the next diff chunk.
   */
  nextDiff() {
    if(this._isSelectionActive) {
      this._selectedChunkIndex++;
      if(this._selectedChunkIndex >= this.getNumDifferences()) {
        this._selectedChunkIndex = 0;
      }
    } else {
      this._isSelectionActive = true;
    }

    this._selectChunk(this._selectedChunkIndex, true);
    return this._selectedChunkIndex;
  }

  /**
   * Called to move the current selection highlight to the previous diff chunk.
   */
  prevDiff() {
    if(this._isSelectionActive) {
      this._selectedChunkIndex--;
      if(this._selectedChunkIndex < 0) {
        this._selectedChunkIndex = this.getNumDifferences() - 1
      }
    } else {
      this._isSelectionActive = true;
    }

    this._selectChunk(this._selectedChunkIndex, true);
    return this._selectedChunkIndex;
  }

  /**
   * Copies the currently selected diff chunk from the left editor to the right
   * editor.
   */
  copyToRight() {
    var foundSelection = false;
    var offset = 0; // keep track of line offset (used when there are multiple chunks being moved)

    for(var diffChunk of this._chunks) {
      if(diffChunk.isSelected) {
        foundSelection = true;

        var textToCopy = this._editorDiffExtender1.getEditor().getTextInBufferRange([[diffChunk.oldLineStart, 0], [diffChunk.oldLineEnd, 0]]);
        var lastBufferRow = this._editorDiffExtender2.getEditor().getLastBufferRow();

        // insert new line if the chunk we want to copy will be below the last line of the other editor
        if((diffChunk.newLineStart + offset) > lastBufferRow) {
          this._editorDiffExtender2.getEditor().setCursorBufferPosition([lastBufferRow, 0], {autoscroll: false});
          this._editorDiffExtender2.getEditor().insertNewline();
        }

        this._editorDiffExtender2.getEditor().setTextInBufferRange([[diffChunk.newLineStart + offset, 0], [diffChunk.newLineEnd + offset, 0]], textToCopy);
        // offset will be the amount of lines to be copied minus the amount of lines overwritten
        offset += (diffChunk.oldLineEnd - diffChunk.oldLineStart) - (diffChunk.newLineEnd - diffChunk.newLineStart);
        // move the selection pointer back so the next diff chunk is not skipped
        if(this._editorDiffExtender1.hasSelection() || this._editorDiffExtender2.hasSelection()) {
          this._selectedChunkIndex--;
        }
      }
    }

    if(!foundSelection) {
      atom.notifications.addWarning('Split Diff', {detail: this._COPY_HELP_MESSAGE, dismissable: false, icon: 'diff'});
    }
  }

  /**
   * Copies the currently selected diff chunk from the right editor to the left
   * editor.
   */
  copyToLeft() {
    var foundSelection = false;
    var offset = 0; // keep track of line offset (used when there are multiple chunks being moved)

    for(var diffChunk of this._chunks) {
      if(diffChunk.isSelected) {
        foundSelection = true;

        var textToCopy = this._editorDiffExtender2.getEditor().getTextInBufferRange([[diffChunk.newLineStart, 0], [diffChunk.newLineEnd, 0]]);
        var lastBufferRow = this._editorDiffExtender1.getEditor().getLastBufferRow();
        // insert new line if the chunk we want to copy will be below the last line of the other editor
        if((diffChunk.oldLineStart + offset) > lastBufferRow) {
          this._editorDiffExtender1.getEditor().setCursorBufferPosition([lastBufferRow, 0], {autoscroll: false});
          this._editorDiffExtender1.getEditor().insertNewline();
        }

        this._editorDiffExtender1.getEditor().setTextInBufferRange([[diffChunk.oldLineStart + offset, 0], [diffChunk.oldLineEnd + offset, 0]], textToCopy);
        // offset will be the amount of lines to be copied minus the amount of lines overwritten
        offset += (diffChunk.newLineEnd - diffChunk.newLineStart) - (diffChunk.oldLineEnd - diffChunk.oldLineStart);
        // move the selection pointer back so the next diff chunk is not skipped
        if(this._editorDiffExtender1.hasSelection() || this._editorDiffExtender2.hasSelection()) {
          this._selectedChunkIndex--;
        }
      }
    }

    if(!foundSelection) {
      atom.notifications.addWarning('Split Diff', {detail: this._COPY_HELP_MESSAGE, dismissable: false, icon: 'diff'});
    }
  }

  /**
   * Cleans up the editor indicated by index. A clean up will remove the editor
   * or the pane if necessary. Typically left editor == 1 and right editor == 2.
   *
   * @param editorIndex The index of the editor to clean up.
   */
  cleanUpEditor(editorIndex) {
    if(editorIndex === 1) {
      this._editorDiffExtender1.cleanUp();
    } else if(editorIndex === 2) {
      this._editorDiffExtender2.cleanUp();
    }
  }

  /**
   * Destroys the editor diff extenders.
   */
  destroy() {
    this._editorDiffExtender1.destroy();
    this._editorDiffExtender2.destroy();
  }

  /**
   * Gets the number of differences between the editors.
   *
   * @return int The number of differences between the editors.
   */
  getNumDifferences() {
    return Array.isArray(this._chunks) ? this._chunks.length : 0;
  }

  getMarkerLayers() {
    return this._markerLayers;
  }

  handleCursorChange(cursor, oldBufferPosition, newBufferPosition) {
    var editorIndex = (cursor.editor === this._editorDiffExtender1.getEditor()) ? 1 : 2;
    var oldPositionChunkIndex = this._getChunkIndexByLineNumber(editorIndex, oldBufferPosition.row);
    var newPositionChunkIndex = this._getChunkIndexByLineNumber(editorIndex, newBufferPosition.row);

    if(oldPositionChunkIndex >= 0) {
      var diffChunk = this._chunks[oldPositionChunkIndex];
      diffChunk.isSelected = false;
      this._editorDiffExtender1.deselectLines(diffChunk.oldLineStart, diffChunk.oldLineEnd);
      this._editorDiffExtender2.deselectLines(diffChunk.newLineStart, diffChunk.newLineEnd);
    }
    if(newPositionChunkIndex >= 0) {
      this._selectChunk(newPositionChunkIndex, false);
    }
  }

  // ----------------------------------------------------------------------- //
  // --------------------------- PRIVATE METHODS --------------------------- //
  // ----------------------------------------------------------------------- //

  /**
   * Selects and highlights the diff chunk in both editors according to the
   * given index.
   *
   * @param index The index of the diff chunk to highlight in both editors.
   */
  _selectChunk(index, isNextOrPrev) {
    var diffChunk = this._chunks[index];
    if(diffChunk != null) {
      diffChunk.isSelected = true;

      if(isNextOrPrev) {
        // deselect previous next/prev highlights
        this._editorDiffExtender1.deselectAllLines();
        this._editorDiffExtender2.deselectAllLines();
        // scroll the editors
        this._editorDiffExtender1.getEditor().setCursorBufferPosition([diffChunk.oldLineStart, 0], {autoscroll: true});
        this._editorDiffExtender2.getEditor().setCursorBufferPosition([diffChunk.newLineStart, 0], {autoscroll: true});
      }

      // highlight selection in both editors
      this._editorDiffExtender1.selectLines(diffChunk.oldLineStart, diffChunk.oldLineEnd);
      this._editorDiffExtender2.selectLines(diffChunk.newLineStart, diffChunk.newLineEnd);
    }
  }

  _getChunkIndexByLineNumber(editorIndex, lineNumber) {
    for(var i=0; i<this._chunks.length; i++) {
      var diffChunk = this._chunks[i];
      if(editorIndex === 1) {
        if(diffChunk.oldLineStart <= lineNumber && diffChunk.oldLineEnd > lineNumber) {
          return i;
        }
      } else if(editorIndex === 2) {
        if(diffChunk.newLineStart <= lineNumber && diffChunk.newLineEnd > lineNumber) {
          return i;
        }
      }
    }

    return -1;
  }

  /**
   * Highlights the word diff of the chunk passed in.
   *
   * @param chunk The chunk that should have its words highlighted.
   */
  _highlightWordsInChunk(chunk, leftHighlightType, rightHighlightType, isWhitespaceIgnored) {
    var leftLineNumber = chunk.oldLineStart;
    var rightLineNumber = chunk.newLineStart;
    // for each line that has a corresponding line
    while(leftLineNumber < chunk.oldLineEnd && rightLineNumber < chunk.newLineEnd) {
      var editor1LineText = this._editorDiffExtender1.getEditor().lineTextForBufferRow(leftLineNumber);
      var editor2LineText = this._editorDiffExtender2.getEditor().lineTextForBufferRow(rightLineNumber);

      if(editor1LineText == '') {
        // computeWordDiff returns empty for lines that are paired with empty lines
        // need to force a highlight
        this._editorDiffExtender2.setWordHighlights(rightLineNumber, [{changed: true, value: editor2LineText}], rightHighlightType, isWhitespaceIgnored);
      } else if( editor2LineText == '' ) {
        // computeWordDiff returns empty for lines that are paired with empty lines
        // need to force a highlight
        this._editorDiffExtender1.setWordHighlights(leftLineNumber, [{changed: true, value: editor1LineText}], leftHighlightType, isWhitespaceIgnored);
      } else {
        // perform regular word diff
        var wordDiff = ComputeWordDiff.computeWordDiff(editor1LineText, editor2LineText);
        this._editorDiffExtender1.setWordHighlights(leftLineNumber, wordDiff.removedWords, leftHighlightType, isWhitespaceIgnored);
        this._editorDiffExtender2.setWordHighlights(rightLineNumber, wordDiff.addedWords, rightHighlightType, isWhitespaceIgnored);
      }

      leftLineNumber++;
      rightLineNumber++;
    }

    // highlight remaining lines in left editor
    while(leftLineNumber < chunk.oldLineEnd) {
      var editor1LineText = this._editorDiffExtender1.getEditor().lineTextForBufferRow(leftLineNumber);
      this._editorDiffExtender1.setWordHighlights(leftLineNumber, [{changed: true, value: editor1LineText}], leftHighlightType, isWhitespaceIgnored);
      leftLineNumber++;
    }
    // highlight remaining lines in the right editor
    while(rightLineNumber < chunk.newLineEnd) {
      this._editorDiffExtender2.setWordHighlights(rightLineNumber, [{changed: true, value: this._editorDiffExtender2.getEditor().lineTextForBufferRow(rightLineNumber)}], rightHighlightType, isWhitespaceIgnored);
      rightLineNumber++;
    }
  }
};
