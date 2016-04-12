'use babel';

var {CompositeDisposable} = require('atom');

class SyncScroll {

  constructor(editor1: TextEditor, editor2: TextEditor, syncHorizontalScroll: boolean) {
    this._syncHorizontalScroll = syncHorizontalScroll;
    this._subscriptions = new CompositeDisposable();
    this._syncInfo = [{
      editor: editor1,
      editorView: atom.views.getView(editor1),
      scrolling: false,
    }, {
      editor: editor2,
      editorView: atom.views.getView(editor2),
      scrolling: false,
    }];

    this._syncInfo.forEach((editorInfo, i) => {
      // Note that 'onDidChangeScrollTop' isn't technically in the public API.
      this._subscriptions.add(editorInfo.editorView.onDidChangeScrollTop(() => this._scrollPositionChanged(i)));
      // Note that 'onDidChangeScrollLeft' isn't technically in the public API.
      if(this._syncHorizontalScroll) {
        this._subscriptions.add(editorInfo.editorView.onDidChangeScrollLeft(() => this._scrollPositionChanged(i)));
      }
      // bind this so that the editors line up on start of package
      this._subscriptions.add(editorInfo.editor.emitter.on('did-change-scroll-top', () => this._scrollPositionChanged(i)));
    });
  }

  _scrollPositionChanged(changeScrollIndex: number): void {
    var thisInfo  = this._syncInfo[changeScrollIndex];
    var otherInfo = this._syncInfo[1 - changeScrollIndex];

    if (thisInfo.scrolling) {
      return;
    }
    otherInfo.scrolling = true;
    try {
      otherInfo.editorView.setScrollTop(thisInfo.editorView.getScrollTop());
      if(this._syncHorizontalScroll) {
        otherInfo.editorView.setScrollLeft(thisInfo.editorView.getScrollLeft());
      }
    } catch (e) {
      //console.log(e);
    }
    otherInfo.scrolling = false;
  }

  dispose(): void {
    if (this._subscriptions) {
      this._subscriptions.dispose();
      this._subscriptions = null;
    }
  }

  syncPositions(): void {
    var activeTextEditor = atom.workspace.getActiveTextEditor();
    this._syncInfo.forEach((editorInfo, i) => {
      if(editorInfo.editor == activeTextEditor) {
        editorInfo.editor.emitter.emit('did-change-scroll-top', editorInfo.editorView.getScrollTop());
      }
    });
  }
}

module.exports = SyncScroll;
