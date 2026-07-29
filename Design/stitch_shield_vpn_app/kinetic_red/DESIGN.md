---
name: Kinetic Red
colors:
  surface: '#121414'
  surface-dim: '#121414'
  surface-bright: '#383939'
  surface-container-lowest: '#0d0e0f'
  surface-container-low: '#1b1c1c'
  surface-container: '#1f2020'
  surface-container-high: '#292a2a'
  surface-container-highest: '#343535'
  on-surface: '#e3e2e2'
  on-surface-variant: '#e7bdb7'
  inverse-surface: '#e3e2e2'
  inverse-on-surface: '#303031'
  outline: '#ae8882'
  outline-variant: '#5d3f3b'
  surface-tint: '#ffb4a9'
  primary: '#ffb4a9'
  on-primary: '#690001'
  primary-container: '#e2231a'
  on-primary-container: '#fffaff'
  inverse-primary: '#c00005'
  secondary: '#c8c6c5'
  on-secondary: '#313030'
  secondary-container: '#474746'
  on-secondary-container: '#b7b4b4'
  tertiary: '#c8c6c5'
  on-tertiary: '#303030'
  tertiary-container: '#757474'
  on-tertiary-container: '#fffbfb'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad5'
  primary-fixed-dim: '#ffb4a9'
  on-primary-fixed: '#410000'
  on-primary-fixed-variant: '#930003'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1c1b1b'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#e5e2e1'
  tertiary-fixed-dim: '#c8c6c5'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#474746'
  background: '#121414'
  on-background: '#e3e2e2'
  surface-variant: '#343535'
typography:
  headline-xl:
    fontFamily: Hanken Grotesk
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  data-mono:
    fontFamily: JetBrains Mono
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: 0.02em
  label-caps:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 16px
  md: 24px
  lg: 32px
  xl: 48px
  safe-margin: 20px
  gutter: 16px
---

## Brand & Style
The brand personality is authoritative, high-performance, and uncompromisingly secure. This design system targets power users and privacy-conscious individuals who equate speed with precision. 

The aesthetic is a hybrid of **Minimalism** and **Cyber-Technic**. It utilizes a "Vantablack" inspired foundation to create an infinite depth effect, allowing high-chroma red accents to serve as functional beacons for security status. The emotional response is one of total control and "always-on" reliability, moving away from friendly consumer aesthetics toward a professional, mission-critical interface.

## Colors
The palette is built on a high-contrast ratio to ensure legibility in low-light environments. 

- **Primary (Electric Red):** Used exclusively for active connection states, primary calls to action, and critical alerts.
- **Background (Pure Black):** Designed for OLED efficiency and to eliminate visual noise.
- **Surface (Deep Charcoal):** Used for cards, input fields, and modals to create a subtle hierarchy against the pure black background.
- **Accents:** Active states utilize a low-opacity red glow (`rgba(226, 35, 26, 0.15)`) to simulate light emission from hardware LEDs.

## Typography
This design system employs a dual-font strategy. **Hanken Grotesk** provides a sharp, contemporary sans-serif feel for all interface copy, prioritizing readability and a "tech-forward" spirit. For technical data—such as IP addresses, transfer speeds, and connection timers—**JetBrains Mono** is used to reinforce the high-performance, developer-grade nature of the tool.

- **Headlines:** Use heavy weights (700-800) to anchor the page.
- **Data Displays:** Use monospaced fonts for any numerical value that changes rapidly to prevent layout jitter.
- **Hierarchy:** Secondary information is set in `neutral_color_hex` at 14px to maintain focus on the primary connection status.

## Layout & Spacing
The layout follows a **4px baseline grid** to ensure mathematical precision in element alignment. 

- **Mobile:** Uses a fluid 4-column grid with 20px safe margins. Elements are vertically stacked to emphasize the "Connect" button as the primary center of gravity.
- **Desktop/Tablet:** Transitions to a 12-column grid. Sidebars are fixed at 280px, while the main dashboard area utilizes a fluid center-aligned container with a maximum width of 1200px.
- **Rhythm:** Generous vertical padding (32px+) is used between distinct functional blocks (e.g., Server Selection vs. Data Usage) to avoid visual clutter.

## Elevation & Depth
In a strict dark theme, depth is achieved through **tonal layering** and **selective luminosity** rather than traditional shadows.

1.  **Level 0 (Base):** `#0A0A0A` - The void. Used for the main application background.
2.  **Level 1 (Surfaces):** `#161616` - Used for cards and persistent navigation bars.
3.  **Level 2 (Popovers):** `#222222` - Used for tooltips, menus, and modals. These receive a 1px border of `rgba(255, 255, 255, 0.08)` to define their edges against the dark background.
4.  **Active Depth:** Interactive elements in an "on" state emit a soft `Primary Red` outer glow with a 20px blur and 15% opacity to simulate physical light.

## Shapes
The shape language balances modern approachability with structural rigidity. 

- **Standard Containers:** Cards and input fields use a **12px (0.75rem)** radius.
- **Buttons:** All buttons use a **full pill-shape** (100px+ radius) to distinguish them clearly from informational containers and suggest a "toggle" or "switch" metaphor.
- **Status Indicators:** Small indicators (like server pings) are perfect circles.
- **Stroke Weight:** All icons and borders should maintain a consistent 1.5px or 2px weight to match the visual density of the typography.

## Components

### Buttons
- **Primary:** Solid `#E2231A` with `#F2F2F2` text. Pill-shaped. Used for "Connect" or "Upgrade."
- **Secondary:** Surface-colored background (`#161616`) with a 1px border of `#8A8A8A`.
- **Ghost:** No background, red text, used for destructive or secondary navigation actions.

### Inputs
- **Text Fields:** `#161616` background with a 1px `#333333` border. On focus, the border transitions to `#E2231A` with a subtle inner glow.
- **Switches:** Custom track in dark gray; the thumb turns solid Red when toggled "on," accompanied by a low-opacity red glow behind the component.

### Cards & Lists
- **Server Selection:** List items utilize a 1px bottom divider of `rgba(255,255,255,0.05)`. Active server selection is indicated by a vertical 4px red "power bar" on the far left edge of the list item.
- **Stat Cards:** Background `#161616`, headlines in `data-mono` (monospaced) for real-time updates.

### Navigation
- **Bottom Tab Bar:** Solid `#0A0A0A` background with a blurred backdrop filter. Active icons are solid Red; inactive icons are outlined Gray. 
- **Shield Logo:** The central brand mark should use 2px line-art, appearing as a stroke-only element when disconnected and a glowing red-filled element when connected.