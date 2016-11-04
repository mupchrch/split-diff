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
  }

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
   * Gets the editor diff abstractions.
   *
   * @return EditorDiffExtender Array containing the editors being diffed.
   */
  getEditorDiffExtenders() {
    return [this._editorDiffExtender1, this._editorDiffExtender2];
  }
};
