'use babel'

module.exports = class BufferExtender {
  _buffer: Object;

  constructor(buffer) {
    this._buffer = buffer;
  }

  /**
   * Gets the line ending for the buffer.
   *
   * @return The line ending as a string.
   */
  getLineEnding(): string {
    let lineEndings = new Set();
    for (let i = 0; i < this._buffer.getLineCount() - 1; i++) {
      lineEndings.add(this._buffer.lineEndingForRow(i));
    }

    if (lineEndings.size > 1) {
      return 'Mixed';
    } else if (lineEndings.has('\n')) {
      return '\n';
    } else if (lineEndings.has('\r\n')) {
      return '\r\n';
    } else if (lineEndings.has('\r')) {
      return '\r';
    } else {
      return '';
    }
  }
};
