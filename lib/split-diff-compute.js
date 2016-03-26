'use babel';

type TextDiff = {
  addedLines: Array<number>;
  removedLines: Array<number>;
  oldLineOffsets: {[lineNumber: string]: number};
  newLineOffsets: {[lineNumber: string]: number};
};

type DiffChunk = {
  addedLines: Array<number>;
  removedLines: Array<number>;
  chunks: Array<any>;
};

function computeWordDiff(oldText: string, newText: string, isWhitespaceIgnored: boolean): WordDiff {
  var JsDiff = require('diff');
  var wordDiff = JsDiff.diffWordsWithSpace(oldText, newText);

  var addedWords = [];
  var removedWords = [];

  // split into two lists: added + removed
  wordDiff.forEach(part => {
    if(part.added) {
      part.changed = true;
      addedWords.push(part);
    } else if(part.removed) {
      part.changed = true;
      removedWords.push(part);
    } else {
      addedWords.push(part);
      removedWords.push(part);
    }
  })

  return {
    addedWords,
    removedWords,
  };
}

function computeDiff(oldText: string, newText: string, isWhitespaceIgnored: boolean): TextDiff {
  var {addedLines, removedLines, chunks} = _computeDiffChunks(oldText, newText, isWhitespaceIgnored);
  var {oldLineOffsets, newLineOffsets} = _computeOffsets(chunks);

  return {
    addedLines,
    removedLines,
    oldLineOffsets,
    newLineOffsets,
    chunks,
  };
}

function _computeDiffChunks(oldText: string, newText: string, isWhitespaceIgnored: boolean): DiffChunk {
  var JsDiff = require('diff');

  // If the last line has changes, JsDiff doesn't return that.
  // Generally, content with new line ending are easier to calculate offsets for.
  if (oldText[oldText.length - 1] !== '\n' || newText[newText.length - 1] !== '\n') {
    oldText += '\n';
    newText += '\n';
  }

  var lineDiff;
  if(isWhitespaceIgnored){
    lineDiff = JsDiff.diffTrimmedLines(oldText, newText);
  } else {
    lineDiff = JsDiff.diffLines(oldText, newText);
  }

  var chunks = [];
  var addedCount = 0;
  var removedCount = 0;
  var nextOffset = 0;
  var offset = 0;

  var addedLines = [];
  var removedLines = [];
  lineDiff.forEach(part => {
    var {added, removed, value} = part;
    var count = value.split('\n').length - 1;
    if (!added && !removed) {
      addedCount += count;
      removedCount += count;
      offset = nextOffset;
      nextOffset = 0;
    } else if (added) {
      for (var i = 0; i < count; i++) {
        addedLines.push(addedCount + i);
      }
      addedCount += count;
      nextOffset += count;
    } else {
      for (var i = 0; i < count; i++) {
        removedLines.push(removedCount + i);
      }
      removedCount += count;
      nextOffset -= count;
    }
    chunks.push({added, removed, value, count, offset});
    offset = 0;
  });
  return {addedLines, removedLines, chunks};
}

function _computeOffsets(diffChunks: Array<any>): {oldLineOffsets: any; newLineOffsets: any;} {
  var newLineOffsets = {};
  var oldLineOffsets = {};

  var oldLineCount = 0;
  var newLineCount = 0;

  for (var chunk of diffChunks) {
    var {added, removed, offset, count} = chunk;
    if (added) {
      newLineCount += count;
    } else if (removed) {
      oldLineCount += count;
    } else {
      if (offset < 0) {
        // Non zero offset implies this block is neither a removal or an addition,
        // and is thus equal in both versions of the document.
        // Sign of offset indicates which version of document requires the offset
        // (negative -> old version, positive -> new version).
        // Magnitude of offset indicates the number of lines of offset required for respective version.
        newLineOffsets[newLineCount] = offset * -1;
      } else if (offset > 0) {
        oldLineOffsets[oldLineCount] = offset;
      }
      newLineCount += count;
      oldLineCount += count;
    }
  }

  return {
    oldLineOffsets,
    newLineOffsets,
  };
}

module.exports = {
  computeDiff,
  computeWordDiff
};
