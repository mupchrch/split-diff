'use babel';

function computeWordDiff(oldText: string, newText: string, isWhitespaceIgnored: boolean): WordDiff {
  var JsDiff = require('diff');
  var wordDiff = JsDiff.diffWordsWithSpace(oldText, newText);

  var addedWords = [];
  var removedWords = [];

  // split into two lists: added + removed
  wordDiff.forEach(part => {
    if (part.added) {
      part.changed = true;
      addedWords.push(part);
    } else if (part.removed) {
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

module.exports = {
  computeWordDiff
};
