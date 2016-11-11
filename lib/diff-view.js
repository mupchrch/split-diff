'use babel'

import EditorDiffExtender from './editor-diff-extender';

module.exports = class DiffView {
  /*
   * @param editors Array of editors being diffed.
   * @param diff ex: {
   *                    addedLines: [startIndex, endIndex],
   *                    removedLines: [startIndex, endIndex],
   *                    oldLineOffsets: [lineNumber: numOffsetLines, ...],
   *                    newLineOffsets: [lineNumber: numOffsetLines, ...],
   *                    chunks: [{
   *                                newLineStart: (int),
   *                                newLineEnd: (int),
   *                                oldLineStart: (int),
   *                                oldLineEnd: (int)
   *                            }, ...]
   *                 }
   */
  constructor( editors, diff ) {
    this._editorDiffExtender1 = new EditorDiffExtender( editors.editor1 );
    this._editorDiffExtender2 = new EditorDiffExtender( editors.editor2 );
    this._chunks = diff.chunks;
    this._isSelectionActive = false;
    this._selectedChunkIndex = 0;
    this._COPY_HELP_MESSAGE = 'Place your cursor in a chunk first!';
  }

  /**
   * Called to move the current selection highlight to the next diff chunk.
   */
  nextDiff() {
    if( this._isSelectionActive ) {
      this._selectedChunkIndex++;
      if( this._selectedChunkIndex >= this._chunks.length ) {
        this._selectedChunkIndex = 0;
      }
    } else {
      this._isSelectionActive = true;
    }

    this._selectChunk( this._selectedChunkIndex );
    return this._selectedChunkIndex;
  }

  /**
   * Called to move the current selection highlight to the previous diff chunk.
   */
  prevDiff() {
    if( this._isSelectionActive ) {
      this._selectedChunkIndex--;
      if( this._selectedChunkIndex < 0 ) {
        this._selectedChunkIndex = this._chunks.length - 1
      }
    } else {
      this._isSelectionActive = true;
    }

    this._selectChunk( this._selectedChunkIndex );
    return this._selectedChunkIndex;
  }

  /**
   * Selects and highlights the diff chunk in both editors according to the
   * given index.
   *
   * @param index The index of the diff chunk to highlight in both editors.
   */
  _selectChunk( index ) {
    var diffChunk = this._chunks[index];
    if( diffChunk != null ) {
      // deselect previous next/prev highlights
      this._editorDiffExtender1.deselectAllLines();
      this._editorDiffExtender2.deselectAllLines();
      // highlight and scroll editor 1
      this._editorDiffExtender1.selectLines( diffChunk.oldLineStart, diffChunk.oldLineEnd );
      this._editorDiffExtender1.getEditor().setCursorBufferPosition( [diffChunk.oldLineStart, 0], {autoscroll: true} );
      // highlight and scroll editor 2
      this._editorDiffExtender2.selectLines( diffChunk.newLineStart, diffChunk.newLineEnd );
      this._editorDiffExtender2.getEditor().setCursorBufferPosition( [diffChunk.newLineStart, 0], {autoscroll: true} );
    }
  }

  /**
   * Copies the currently selected diff chunk from the left editor to the right
   * editor.
   */
  copyToRight() {
    var linesToCopy = this._editorDiffExtender1.getCursorDiffLines();

    if( linesToCopy.length == 0 ) {
      atom.notifications.addWarning('Split Diff', {detail: this._COPY_HELP_MESSAGE, dismissable: false, icon: 'diff'})
    }

    // keep track of line offset (used when there are multiple chunks being moved)
    var offset = 0;

    for( lineRange of linesToCopy ) {
      for( diffChunk of this._chunks ) {
        if( lineRange.start.row == diffChunk.oldLineStart ) {
          var textToCopy = this._editorDiffExtender1.getEditor().getTextInBufferRange( [[diffChunk.oldLineStart, 0], [diffChunk.oldLineEnd, 0]] );
          var lastBufferRow = this._editorDiffExtender2.getEditor().getLastBufferRow();

          // insert new line if the chunk we want to copy will be below the last line of the other editor
          if( (diffChunk.newLineStart + offset) > lastBufferRow ) {
            this._editorDiffExtender2.getEditor().setCursorBufferPosition( [lastBufferRow, 0], {autoscroll: false} );
            this._editorDiffExtender2.getEditor().insertNewline();
          }

          this._editorDiffExtender2.getEditor().setTextInBufferRange( [[diffChunk.newLineStart + offset, 0], [diffChunk.newLineEnd + offset, 0]], textToCopy );
          // offset will be the amount of lines to be copied minus the amount of lines overwritten
          offset += (diffChunk.oldLineEnd - diffChunk.oldLineStart) - (diffChunk.newLineEnd - diffChunk.newLineStart);
          // move the selection pointer back so the next diff chunk is not skipped
          if( this._editorDiffExtender1.hasSelection() || this._editorDiffExtender2.hasSelection() ) {
            this._selectedChunkIndex--;
          }
        }
      }
    }
  }

  /**
   * Copies the currently selected diff chunk from the right editor to the left
   * editor.
   */
  copyToLeft() {
    var linesToCopy = this._editorDiffExtender2.getCursorDiffLines();

    if( linesToCopy.length == 0 ) {
      atom.notifications.addWarning( 'Split Diff', {detail: this._COPY_HELP_MESSAGE, dismissable: false, icon: 'diff'} );
    }

    var offset = 0; // keep track of line offset (used when there are multiple chunks being moved)
    for( lineRange of linesToCopy ) {
      for( diffChunk of this._chunks ) {
        if( lineRange.start.row == diffChunk.newLineStart ) {
          var textToCopy = this._editorDiffExtender2.getEditor().getTextInBufferRange( [[diffChunk.newLineStart, 0], [diffChunk.newLineEnd, 0]] );
          var lastBufferRow = this._editorDiffExtender1.getEditor().getLastBufferRow();
          // insert new line if the chunk we want to copy will be below the last line of the other editor
          if( (diffChunk.oldLineStart + offset) > lastBufferRow ) {
            this._editorDiffExtender1.getEditor().setCursorBufferPosition( [lastBufferRow, 0], {autoscroll: false} );
            this._editorDiffExtender1.getEditor().insertNewline();
          }

          this._editorDiffExtender1.getEditor().setTextInBufferRange( [[diffChunk.oldLineStart + offset, 0], [diffChunk.oldLineEnd + offset, 0]], textToCopy );
          // offset will be the amount of lines to be copied minus the amount of lines overwritten
          offset += (diffChunk.newLineEnd - diffChunk.newLineStart) - (diffChunk.oldLineEnd - diffChunk.oldLineStart);
          // move the selection pointer back so the next diff chunk is not skipped
          if( this._editorDiffExtender1.hasSelection() || this._editorDiffExtender2.hasSelection() ) {
            this._selectedChunkIndex--;
          }
        }
      }
    }
  }

  /**
   * Gets the editor diff abstractions.
   *
   * @return EditorDiffExtender Array containing the editors being diffed.
   */
  getEditorDiffExtenders() {
    return [this._editorDiffExtender1, this._editorDiffExtender2];
  }
};
