fs = require('fs');

var oldTextPath = process.argv[2];
var newTextPath = process.argv[3];
var isWhitespaceIgnored = process.argv[4];

var oldText = fs.readFileSync(oldTextPath);
var newText = fs.readFileSync(newTextPath);

var diffChunks = _computeDiffChunks(oldText, newText, isWhitespaceIgnored);
var offsets = _computeOffsets(diffChunks.chunks);

console.log( JSON.stringify({
  addedLines: diffChunks.addedLines,
  removedLines: diffChunks.removedLines,
  oldLineOffsets: offsets.oldLineOffsets,
  newLineOffsets: offsets.newLineOffsets,
  chunks: diffChunks.chunks,
}));


function _computeDiffChunks(oldText, newText, isWhitespaceIgnored) {
  var JsDiff = require('diff');

  // If the last line has changes, JsDiff doesn't return that.
  // Generally, content with new line ending are easier to calculate offsets for.
  if (oldText[oldText.length - 1] !== '\n' || newText[newText.length - 1] !== '\n') {
    oldText += '\n';
    newText += '\n';
  }

  var lineDiff;
  if (isWhitespaceIgnored) {
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
  lineDiff.forEach( function(part) {
    var added = part.added,
      removed = part.removed,
      value = part.value;
    var count = part.count;//value.split('\n').length - 1;
    if (!added && !removed) {
      addedCount += count;
      removedCount += count;
      offset = nextOffset;
      nextOffset = 0;
    } else if (added) {
      addedLines.push([addedCount, addedCount+count])
      addedCount += count;
      nextOffset += count;
    } else {
      removedLines.push([removedCount, removedCount+count])
      removedCount += count;
      nextOffset -= count;
    }
    chunks.push({
      added: added,
      removed: removed,
      value: value,
      count: count,
      offset: offset
    });
    offset = 0;
  });

  return {
    addedLines: addedLines,
    removedLines: removedLines,
    chunks: chunks,
  };
}

function _computeOffsets(diffChunks) {
  var newLineOffsets = {};
  var oldLineOffsets = {};
  var oldLineCount = 0;
  var newLineCount = 0;
  for (var _i = 0, diffChunks_1 = diffChunks; _i < diffChunks_1.length; _i++) {
    var chunk = diffChunks_1[_i];
    var added = chunk.added, removed = chunk.removed, offset = chunk.offset, count = chunk.count;
    if (added) {
      newLineCount += count;
    }
    else if (removed) {
      oldLineCount += count;
    }
    else {
      if (offset < 0) {
        // Non zero offset implies this block is neither a removal or an addition,
        // and is thus equal in both versions of the document.
        // Sign of offset indicates which version of document requires the offset
        // (negative -> old version, positive -> new version).
        // Magnitude of offset indicates the number of lines of offset required for respective version.
        newLineOffsets[newLineCount] = offset * -1;
      }
      else if (offset > 0) {
        oldLineOffsets[oldLineCount] = offset;
      }
      newLineCount += count;
      oldLineCount += count;
    }
  }
  return {
    oldLineOffsets: oldLineOffsets,
    newLineOffsets: newLineOffsets,
  };
}
