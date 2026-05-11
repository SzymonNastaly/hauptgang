import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="portion-scaler"
//
// Scales each ingredient row's quantity in-place when the servings input
// changes. No fetch, pure DOM. Rows that have no `data-base-amount` are
// left untouched (e.g. "pinch of salt").
export default class extends Controller {
  static targets = ["quantity", "servingsInput"];
  static values = { baseServings: Number };

  connect() {
    // Cache the base servings as the initial input value if no value was set
    if (!this.hasBaseServingsValue || this.baseServingsValue <= 0) {
      const initial = this.hasServingsInputTarget
        ? parseFloat(this.servingsInputTarget.value)
        : NaN;
      this.baseServingsValue = Number.isFinite(initial) && initial > 0 ? initial : 1;
    }
  }

  rescale() {
    const current = this.hasServingsInputTarget
      ? parseFloat(this.servingsInputTarget.value)
      : NaN;
    if (!Number.isFinite(current) || current <= 0) return;

    const factor = current / this.baseServingsValue;

    this.quantityTargets.forEach((el) => {
      const baseAmount = parseFloat(el.dataset.baseAmount);
      const baseAmountMax = parseFloat(el.dataset.baseAmountMax);
      const unit = el.dataset.unit || "";

      if (!Number.isFinite(baseAmount)) return; // unit-only / unparsed

      const scaled = this._formatNumber(baseAmount * factor);
      let quantity = scaled;
      if (Number.isFinite(baseAmountMax)) {
        quantity = `${scaled}\u2013${this._formatNumber(baseAmountMax * factor)}`;
      }

      el.textContent = unit ? `${quantity} ${unit}` : quantity;
    });
  }

  _formatNumber(n) {
    // Round to 2 decimals, drop trailing zeros, then map common fractions to glyphs.
    const rounded = Math.round(n * 100) / 100;
    const fraction = this._unicodeFraction(rounded);
    if (fraction !== null) return fraction;

    let s = rounded.toFixed(2);
    s = s.replace(/\.?0+$/, "");
    return s;
  }

  _unicodeFraction(value) {
    // Match the helper-side mapping; tolerance matches recipes_helper.
    const map = [
      [0.25, "\u00BC"],
      [0.5, "\u00BD"],
      [0.75, "\u00BE"],
      [0.3333, "\u2153"],
      [0.6667, "\u2154"],
      [0.125, "\u215B"],
      [0.375, "\u215C"],
      [0.625, "\u215D"],
      [0.875, "\u215E"],
    ];
    for (const [key, glyph] of map) {
      if (Math.abs(value - key) < 0.005) return glyph;
    }
    return null;
  }
}
