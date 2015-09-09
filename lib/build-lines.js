/*
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the LICENSE file in
 * the root directory of this source tree.
 */

/*
 * @param screenLines The original screen lines before adding offsets.
 * @param lineOffsets The offset map from buffer line numbers to the number of lines of offset requested there.
 * @param startBufferRow The buffer row at which the next range of screen lines is started.
 * @param endBufferRow The buffer row at which the next range of screen lines is ended.
 * @param emptyLineFactory A custom function to create a new empty line, representing an offset screen line.
 */
function buildLineRangesWithOffsets(screenLines, lineOffsets, startBufferRow, endBufferRow, emptyLineFactory) {

  var offsetLineNumbers = Object.keys(lineOffsets).map(function (lineNumber) {
    return parseInt(lineNumber, 10);
  }).sort(function (x, y) {
    return x - y;
  });

  var priorScreenLine = startBufferRow;
  var newRegions = [];
  var newScreenLines = [];

  var captureScreenLinesRegion = function captureScreenLinesRegion(toScreenLine) {
    if (toScreenLine < priorScreenLine) {
      return;
    }
    var numberOfRows = toScreenLine - priorScreenLine;
    if (numberOfRows > 0) {
      // Add the portion of the original screenLines until toScreenLine.
      newScreenLines.push.apply(newScreenLines, screenLines.slice(priorScreenLine - startBufferRow, toScreenLine - startBufferRow));
      // This is normal 1 to 1 buffer to screen row region.
      newRegions.push({ bufferRows: numberOfRows, screenRows: numberOfRows });
    }
    priorScreenLine = toScreenLine + 1;
  };

  // Construct the new screen lines and regions, by adding empty lines at the offset lines
  // and returning ranges with screenRows = bufferRows + offsetLines.
  var _iteratorNormalCompletion = true;
  var _didIteratorError = false;
  var _iteratorError = undefined;

  try {
    for (var _iterator = offsetLineNumbers[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
      var offsetLineNumber = _step.value;

      if (offsetLineNumber < priorScreenLine || offsetLineNumber >= endBufferRow) {
        continue;
      }
      var offsetLines = lineOffsets[offsetLineNumber];
      captureScreenLinesRegion(offsetLineNumber - 1);
      // Add empty screen lines to represent offsets.
      for (var i = 0; i < offsetLines; i++) {
        newScreenLines.push(emptyLineFactory());
      }
      var startOffsetBufferLineNumber = offsetLineNumber - startBufferRow - 1;
      // TODO: fix when we have more control on the buffer to screen line mapping
      // Currently, if we have offsets at the begining of the file, the gutter numbering would be confusing
      // because it considers the first offset line is the line to be numbered.
      if (startOffsetBufferLineNumber >= 0) {
        // The buffer line should be inserted above the empty offset lines added.
        newScreenLines.splice(newScreenLines.length - offsetLines, 0, screenLines[startOffsetBufferLineNumber]);
      } else {
        // startOffsetBufferLineNumber = -1 in case the offsets are in the begining of the file.
        newScreenLines.push(screenLines[0]);
        priorScreenLine++;
      }
      newRegions.push({ bufferRows: 1, screenRows: offsetLines + 1 });
    }

    // Capture a single region to the end of the screen lines.
  } catch (err) {
    _didIteratorError = true;
    _iteratorError = err;
  } finally {
    try {
      if (!_iteratorNormalCompletion && _iterator['return']) {
        _iterator['return']();
      }
    } finally {
      if (_didIteratorError) {
        throw _iteratorError;
      }
    }
  }

  captureScreenLinesRegion(endBufferRow);

  return { regions: newRegions, screenLines: newScreenLines };
}

module.exports = {
  buildLineRangesWithOffsets,
};
