'use babel'

import EditorDiffExtender from './editor-diff-extender';

module.exports = class DiffView {
  _editorDiffExtender1;
  _editorDiffExtender2;
  //TODO finish this
  /*_isFirstChunkSelected;
  _diffChunkPointer;*/

  constructor( editors ) {
    this._editorDiffExtender1 = new EditorDiffExtender( editors.editor1 );
    this._editorDiffExtender2 = new EditorDiffExtender( editors.editor2 );
    //TODO finish this
    //this._isFirstChunkSelected = true;
  }

  //TODO finish this
  /*nextDiff() {
    if !this._isFirstChunkSelected
      _diffChunkPointer++
      if _diffChunkPointer >= @linkedDiffChunks.length
        _diffChunkPointer = 0
    else
      this._isFirstChunkSelected = false

    @_selectDiffs(@linkedDiffChunks[_diffChunkPointer], _diffChunkPointer)
  }
  */

  /**
   * Gets the editor diff abstractions.
   *
   * @return EditorDiffExtender Array containing the editors being diffed.
   */
  getEditorDiffExtenders() {
    return [this._editorDiffExtender1, this._editorDiffExtender2];
  }
};
