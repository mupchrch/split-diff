module.exports =
class LoadingView
  constructor: () ->
    # Create root element
    @element = document.createElement('div')
    @element.classList.add('split-diff-modal')

    # Create icon element
    icon = document.createElement('div')
    icon.classList.add('split-diff-icon')
    @element.appendChild(icon)

    # Create message element
    message = document.createElement('div')
    message.textContent = "Computing the diff for you."
    message.classList.add('split-diff-message')
    messageOuter = document.createElement('div')
    messageOuter.appendChild(message)
    @element.appendChild(messageOuter)

  # Tear down any state and detach
  destroy: ->
    @element.remove()
    @modalPanel.destroy()

  getElement: ->
    @element

  createModal: ->
    @modalPanel = atom.workspace.addModalPanel(item: @element, visible: false)
    @modalPanel.item.parentNode.classList.add('split-diff-hide-mask')

  show: ->
    @modalPanel.show()

  hide: ->
    @modalPanel.hide()
