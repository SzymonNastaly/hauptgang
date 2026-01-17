import { Controller } from "@hotwired/stimulus"
import Masonry from "masonry-layout"

// Connects to data-controller="masonry"
export default class extends Controller {
  connect() {
    // Initial layout
    this.updateLayout()

    // Re-layout on window resize
    this.resizeHandler = () => this.updateLayout()
    window.addEventListener('resize', this.resizeHandler)
  }

  // Calculate column width based on screen size and rebuild layout
  updateLayout() {
    const containerWidth = this.element.offsetWidth
    let columns = 1

    // Adjusted breakpoints to account for sidebar (256px) + padding (48px)
    // These work well for the actual available content width
    if (containerWidth >= 1200) columns = 4      // ~1504px window width
    else if (containerWidth >= 900) columns = 3   // ~1204px window width
    else if (containerWidth >= 600) columns = 2   // ~904px window width

    // Items have px-3 (12px on each side), so gutter is handled by padding
    const columnWidth = containerWidth / columns

    // Set width on all items to match column width
    const items = this.element.querySelectorAll('.masonry-item')
    items.forEach(item => {
      item.style.width = `${columnWidth}px`
    })

    if (this.masonry) {
      this.masonry.destroy()
    }

    this.masonry = new Masonry(this.element, {
      itemSelector: '.masonry-item',
      columnWidth: columnWidth,
      gutter: 0, // Padding handles spacing
      transitionDuration: '0.2s'
    })

    // Add class to trigger CSS fade-in (prevents flash of unstyled content)
    this.element.classList.add('masonry-loaded')
  }

  disconnect() {
    if (this.masonry) {
      this.masonry.destroy()
    }
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler)
    }
  }

  layout() {
    if (this.masonry) {
      this.masonry.reloadItems()
      this.masonry.layout()
    }
  }
}
