module.exports =
class SplitDiffUI
  constructor: () ->
    # create root element
    @element = document.createElement('div')
    @element.classList.add('split-diff-ui')

    # create/add number of differences value
    @numDifferences = document.createElement('div')
    @numDifferences.classList.add('num-diff-value')
    @element.appendChild(@numDifferences)

    # create/add number of differences text
    numDifferencesText = document.createElement('div')
    numDifferencesText.textContent = 'differences found.'
    numDifferencesText.classList.add('num-diff-text')
    @element.appendChild(numDifferencesText)

    # create button group
    buttonsGroup = document.createElement('div')
    buttonsGroup.classList.add('btn-group')

    # create copy to left button
    copyToLeftButton = document.createElement('button')
    copyToLeftButton.classList.add('btn')
    copyToLeftButton.classList.add('btn-sm')
    copyToLeftButton.classList.add('copy-to-left')
    copyToLeftButton.onclick = () -> atom.commands.dispatch(atom.views.getView(atom.workspace), 'split-diff:copy-to-left')
    copyToLeftButton.title = 'Copy To Left'

    # create copy to right button
    copyToRightButton = document.createElement('button')
    copyToRightButton.classList.add('btn')
    copyToRightButton.classList.add('btn-sm')
    copyToRightButton.classList.add('copy-to-right')
    copyToRightButton.onclick = () -> atom.commands.dispatch(atom.views.getView(atom.workspace), 'split-diff:copy-to-right')
    copyToRightButton.title = 'Copy To Right'

    # create prev diff button
    prevDiffButton = document.createElement('button')
    prevDiffButton.classList.add('btn')
    prevDiffButton.classList.add('btn-sm')
    prevDiffButton.classList.add('prev-diff')
    prevDiffButton.onclick = () -> atom.commands.dispatch(atom.views.getView(atom.workspace), 'split-diff:prev-diff')
    prevDiffButton.title = 'Prev Diff'

    # create next diff button
    nextDiffButton = document.createElement('button')
    nextDiffButton.classList.add('btn')
    nextDiffButton.classList.add('btn-sm')
    nextDiffButton.classList.add('next-diff')
    nextDiffButton.onclick = () -> atom.commands.dispatch(atom.views.getView(atom.workspace), 'split-diff:next-diff')
    nextDiffButton.title = 'Next Diff'

    # add buttons to button group
    buttonsGroup.appendChild(copyToLeftButton)
    buttonsGroup.appendChild(copyToRightButton)
    buttonsGroup.appendChild(prevDiffButton)
    buttonsGroup.appendChild(nextDiffButton)

    # add button group to root
    @element.appendChild(buttonsGroup)

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
    @numDifferences.textContent = num
