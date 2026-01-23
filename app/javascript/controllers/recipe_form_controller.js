import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="recipe-form"
export default class extends Controller {
  static targets = [
    "ingredientsList",
    "ingredientTemplate",
    "instructionsList",
    "instructionTemplate",
    "imagePreview"
  ]

  static values = {
    ingredients: { type: Array, default: [] },
    instructions: { type: Array, default: [] }
  }

  connect() {
    this.loadIngredients()
    this.loadInstructions()
    this.setupDirtyTracking()
  }

  disconnect() {
    // Clean up event listeners to prevent memory leaks during Turbo navigation
    this.element.removeEventListener("input", this.markDirty)
    this.element.removeEventListener("change", this.markDirty)
    this.element.removeEventListener("submit", this.clearDirty)
    window.removeEventListener("beforeunload", this.beforeUnload)
    document.removeEventListener("turbo:before-visit", this.turboBeforeVisit)
  }

  setupDirtyTracking() {
    this.dirty = false

    // Listen for form changes
    this.element.addEventListener("input", this.markDirty)
    this.element.addEventListener("change", this.markDirty)

    // Clear dirty state on form submit (so warning doesn't show after saving)
    this.element.addEventListener("submit", this.clearDirty)

    // Listen for page leave events
    window.addEventListener("beforeunload", this.beforeUnload)
    document.addEventListener("turbo:before-visit", this.turboBeforeVisit)
  }

  // Arrow functions automatically capture 'this' from the surrounding scope
  markDirty = () => {
    this.dirty = true
  }

  clearDirty = () => {
    this.dirty = false
  }

  beforeUnload = (event) => {
    if (this.dirty) {
      event.preventDefault()
      // Modern browsers ignore custom messages, but setting returnValue is required
      event.returnValue = ""
    }
  }

  turboBeforeVisit = (event) => {
    if (this.dirty) {
      if (!confirm("You have unsaved changes. Are you sure you want to leave?")) {
        event.preventDefault()
      }
    }
  }

  loadIngredients() {
    if (this.ingredientsValue.length > 0) {
      this.ingredientsValue.forEach(ingredient => this.addIngredientWithValue(ingredient))
    } else {
      this.addIngredient()
    }
  }

  loadInstructions() {
    if (this.instructionsValue.length > 0) {
      this.instructionsValue.forEach(instruction => this.addInstructionWithValue(instruction))
    } else {
      this.addInstruction()
    }
  }

  addIngredient(event) {
    event?.preventDefault()
    this.addIngredientWithValue('')
  }

  addIngredientWithValue(value, focus = false) {
    const clone = this.ingredientTemplateTarget.content.cloneNode(true)
    const input = clone.querySelector('input')
    input.value = value
    this.ingredientsListTarget.appendChild(clone)

    if (focus) {
      // Need to get the actual DOM element after appending (clone becomes a fragment)
      const lastInput = this.ingredientsListTarget.lastElementChild.querySelector('input')
      lastInput.focus()
    }
  }

  handleIngredientKeydown(event) {
    // When Enter is pressed in an ingredient field, add a new ingredient instead of submitting form
    if (event.key === 'Enter') {
      event.preventDefault()
      this.addIngredientWithValue('', true)
    }
  }

  removeIngredient(event) {
    event.preventDefault()
    const item = event.currentTarget.parentElement

    if (this.ingredientsListTarget.children.length > 1) {
      item.remove()
    } else {
      item.querySelector('input').value = ''
    }
  }

  addInstruction(event) {
    event?.preventDefault()
    this.addInstructionWithValue('')
  }

  addInstructionWithValue(value) {
    const clone = this.instructionTemplateTarget.content.cloneNode(true)
    const textarea = clone.querySelector('textarea')
    textarea.value = value
    this.instructionsListTarget.appendChild(clone)
    this.updateInstructionNumbers()
  }

  removeInstruction(event) {
    event.preventDefault()
    const item = event.currentTarget.closest('.group')

    if (this.instructionsListTarget.children.length > 1) {
      item.remove()
      this.updateInstructionNumbers()
    } else {
      item.querySelector('textarea').value = ''
    }
  }

  updateInstructionNumbers() {
    this.instructionsListTarget.querySelectorAll('[data-step-number]').forEach((el, index) => {
      el.textContent = index + 1
    })
  }

  handleImageUpload(event) {
    const file = event.target.files[0]
    if (file) {
      const reader = new FileReader()
      reader.onload = (e) => {
        this.imagePreviewTarget.innerHTML = `
          <img src="${e.target.result}" alt="Cover preview" class="w-full h-full object-cover" />
          <div class="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-white font-medium">
            Change Photo
          </div>
        `
      }
      reader.readAsDataURL(file)
    }
  }
}
