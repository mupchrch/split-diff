module.exports =
class SplitDiffUI
  constructor: (isWhitespaceIgnored) ->
    # create root element
    @element = document.createElement('div')
    @element.classList.add('split-diff-ui')

    # create number of differences value
    @numDifferencesValue = document.createElement('span')
    @numDifferencesValue.classList.add('num-diff-value')
    # create number of differences text
    numDifferencesText = document.createElement('span')
    numDifferencesText.textContent = 'differences found.'
    numDifferencesText.classList.add('num-diff-text')
    # create number of differences container
    numDifferences = document.createElement('div')
    numDifferences.classList.add('num-diff')
    # add items to container
    numDifferences.appendChild(@numDifferencesValue)
    numDifferences.appendChild(numDifferencesText)
    # add container to UI
    @element.appendChild(numDifferences)

    # create copy to left button
    copyToLeftButton = document.createElement('button')
    copyToLeftButton.classList.add('btn')
    copyToLeftButton.classList.add('btn-sm')
    copyToLeftButton.classList.add('copy-to-left')
    copyToLeftButton.onclick = () ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'split-diff:copy-to-left')
    copyToLeftButton.title = 'Copy to Left'
    # create copy to right button
    copyToRightButton = document.createElement('button')
    copyToRightButton.classList.add('btn')
    copyToRightButton.classList.add('btn-sm')
    copyToRightButton.classList.add('copy-to-right')
    copyToRightButton.onclick = () ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'split-diff:copy-to-right')
    copyToRightButton.title = 'Copy to Right'
    # create prev diff button
    prevDiffButton = document.createElement('button')
    prevDiffButton.classList.add('btn')
    prevDiffButton.classList.add('btn-sm')
    prevDiffButton.classList.add('prev-diff')
    prevDiffButton.onclick = () ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'split-diff:prev-diff')
    prevDiffButton.title = 'Move to Previous Diff'
    # create next diff button
    nextDiffButton = document.createElement('button')
    nextDiffButton.classList.add('btn')
    nextDiffButton.classList.add('btn-sm')
    nextDiffButton.classList.add('next-diff')
    nextDiffButton.onclick = () ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'split-diff:next-diff')
    nextDiffButton.title = 'Move to Next Diff'
    # create button group
    buttonsGroup = document.createElement('div')
    buttonsGroup.classList.add('btn-group')
    # add buttons to button group
    buttonsGroup.appendChild(copyToLeftButton)
    buttonsGroup.appendChild(copyToRightButton)
    buttonsGroup.appendChild(prevDiffButton)
    buttonsGroup.appendChild(nextDiffButton)
    # add button group to UI
    @element.appendChild(buttonsGroup)

    # create selection counter
    @selectionCountValue = document.createElement('span')
    @selectionCountValue.classList.add('selection-count-value')
    @element.appendChild(@selectionCountValue)
    # create selection divider
    selectionDivider = document.createElement('span')
    selectionDivider.textContent = '/'
    selectionDivider.classList.add('selection-divider')
    @element.appendChild(selectionDivider)
    # create selection total
    @selectionTotal = document.createElement('span')
    @selectionTotal.classList.add('selection-total')
    @element.appendChild(@selectionTotal)
    # create selection count container
    @selectionCount = document.createElement('div')
    @selectionCount.classList.add('selection-count')
    @selectionCount.classList.add('hidden')
    # add items to container
    @selectionCount.appendChild(@selectionCountValue)
    @selectionCount.appendChild(selectionDivider)
    @selectionCount.appendChild(@selectionTotal)
    # add container to UI
    @element.appendChild(@selectionCount)

    ignoreWhitespaceValue = document.createElement('input')
    ignoreWhitespaceValue.type = 'checkbox'
    ignoreWhitespaceValue.id = 'ignore-whitespace-checkbox'
    ignoreWhitespaceValue.checked = isWhitespaceIgnored
    ignoreWhitespaceValue.addEventListener('change', () ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'split-diff:ignore-whitespace')
    )
    ignoreWhitespaceLabel = document.createElement('label')
    ignoreWhitespaceLabel.htmlFor = 'ignore-whitespace-checkbox'
    ignoreWhitespaceLabel.textContent = 'Ignore Whitespace'

    settings = document.createElement('div')
    settings.classList.add('settings')
    settings.appendChild(ignoreWhitespaceValue)
    settings.appendChild(ignoreWhitespaceLabel)
    @element.appendChild(settings)

  # Tear down any state and detach
  destroy: ->
    @element.remove()
    @footerPanel.destroy()

  getElement: ->
    @element

  createPanel: ->
    @footerPanel = atom.workspace.addBottomPanel(item: @element)

  show: ->
    @footerPanel.show()

  hide: ->
    @footerPanel.hide()

  setNumDifferences: (num) ->
    @numDifferencesValue.textContent = num
    @selectionTotal.textContent = num

  showSelectionCount: (count) ->
    @selectionCountValue.textContent = count
    @selectionCount.classList.remove('hidden')
