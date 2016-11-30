fs = require( 'fs' );

var oldTextPath = process.argv[2];
var newTextPath = process.argv[3];
var isWhitespaceIgnored = process.argv[4];

var oldText = fs.readFileSync( oldTextPath );
var newText = fs.readFileSync( newTextPath );

var diffChunks = _computeDiffChunks( oldText, newText, isWhitespaceIgnored );
var offsets = _computeOffsets( diffChunks );
var orderedChunks = _orderDiffChunks( diffChunks );

console.log( JSON.stringify({
  oldLineOffsets: offsets.oldLineOffsets,
  newLineOffsets: offsets.newLineOffsets,
  chunks: orderedChunks
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
  if (isWhitespaceIgnored == 'true') {
    lineDiff = JsDiff.diffTrimmedLines(oldText, newText);
  } else {
    lineDiff = JsDiff.diffLines(oldText, newText);
  }

  var chunks = [];
  var nextOffset = 0;
  var offset = 0;

  lineDiff.forEach( function(part) {
    var added = part.added,
      removed = part.removed,
      value = part.value;
    var count = part.count;//value.split('\n').length - 1;
    if (!added && !removed) {
      offset = nextOffset;
      nextOffset = 0;
    } else if (added) {
      nextOffset += count;
    } else {
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

  return chunks;
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

/*
 * puts the chunks into order so nextDiff and prevDiff are in order
 */
function _orderDiffChunks( chunks ) {
  var oldLineNumber = 0;
  var newLineNumber = 0;
  var prevChunk = null;
  // mapping of chunks between the two panes
  var diffChunks = [];

  for( c of chunks ) {
    if( c != null && c.added ) {
      if( prevChunk != null && prevChunk.removed != null) {
        var diffChunk = {
          newLineStart: newLineNumber,
          newLineEnd: newLineNumber + c.count,
          oldLineStart: oldLineNumber - prevChunk.count,
          oldLineEnd: oldLineNumber
        };
        diffChunks.push(diffChunk);
        prevChunk = null;
      } else {
        prevChunk = c;
      }

      newLineNumber += c.count;
    } else if( c.removed != null ) {
      if( prevChunk != null && prevChunk.added != null ) {
        var diffChunk = {
          newLineStart: newLineNumber - prevChunk.count,
          newLineEnd: newLineNumber,
          oldLineStart: oldLineNumber,
          oldLineEnd: oldLineNumber + c.count
        };
        diffChunks.push(diffChunk);
        prevChunk = null;
      } else {
        prevChunk = c;
      }

      oldLineNumber += c.count;
    } else {
      if( prevChunk != null && prevChunk.added != null ) {
        var diffChunk = {
          newLineStart: newLineNumber - prevChunk.count,
          newLineEnd: newLineNumber,
          oldLineStart: oldLineNumber,
          oldLineEnd: oldLineNumber
        };
        diffChunks.push(diffChunk);
      } else if( prevChunk != null && prevChunk.removed != null ) {
        var diffChunk = {
          newLineStart: newLineNumber,
          newLineEnd: newLineNumber,
          oldLineStart: oldLineNumber - prevChunk.count,
          oldLineEnd: oldLineNumber
        };
        diffChunks.push(diffChunk);
      }

      prevChunk = null;
      oldLineNumber += c.count;
      newLineNumber += c.count;
    }
  }

  // add the prevChunk if the loop finished
  if( prevChunk != null && prevChunk.added != null ) {
    var diffChunk = {
      newLineStart: newLineNumber - prevChunk.count,
      newLineEnd: newLineNumber,
      oldLineStart: oldLineNumber,
      oldLineEnd: oldLineNumber
    };
    diffChunks.push(diffChunk);
  } else if( prevChunk != null && prevChunk.removed != null ) {
    var diffChunk = {
      newLineStart: newLineNumber,
      newLineEnd: newLineNumber,
      oldLineStart: oldLineNumber - prevChunk.count,
      oldLineEnd: oldLineNumber
    }
    diffChunks.push(diffChunk);
  }

  return diffChunks;
}
