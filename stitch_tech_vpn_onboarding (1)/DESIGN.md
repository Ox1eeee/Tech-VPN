---
name: Kinetic Red
colors:
  surface: '#1f0f0d'
  surface-dim: '#1f0f0d'
  surface-bright: '#493431'
  surface-container-lowest: '#1a0a08'
  surface-container-low: '#291714'
  surface-container: '#2d1b18'
  surface-container-high: '#392522'
  surface-container-highest: '#45302d'
  on-surface: '#fddbd6'
  on-surface-variant: '#e7bdb7'
  inverse-surface: '#fddbd6'
  inverse-on-surface: '#402b28'
  outline: '#ae8882'
  outline-variant: '#5d3f3b'
  surface-tint: '#ffb4a9'
  primary: '#ffb4a9'
  on-primary: '#690001'
  primary-container: '#e2231a'
  on-primary-container: '#fffaff'
  inverse-primary: '#c00005'
  secondary: '#c8c6c5'
  on-secondary: '#303030'
  secondary-container: '#474746'
  on-secondary-container: '#b6b5b4'
  tertiary: '#a1c9ff'
  on-tertiary: '#00325b'
  tertiary-container: '#0076cc'
  on-tertiary-container: '#fbfbff'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad5'
  primary-fixed-dim: '#ffb4a9'
  on-primary-fixed: '#410000'
  on-primary-fixed-variant: '#930003'
  secondary-fixed: '#e4e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1b1c1b'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#d3e4ff'
  tertiary-fixed-dim: '#a1c9ff'
  on-tertiary-fixed: '#001c38'
  on-tertiary-fixed-variant: '#004880'
  background: '#1f0f0d'
  on-background: '#fddbd6'
  surface-variant: '#45302d'
typography:
  headline-lg:
    fontFamily: Sora
    fontSize: 37px
    fontWeight: '700'
    lineHeight: 44px
  subtitle-sm:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 2px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 21px
    fontWeight: '400'
    lineHeight: 28px
  body-sm:
    fontFamily: Hanken Grotesk
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
  button-label:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 2px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  container-padding: 24px
  stack-gap: 16px
  grid-gutter: 16px
---

## Brand & Style

The design system is engineered for a high-performance VPN utility, emphasizing speed, security, and technical precision. The aesthetic is **Modern-Industrial with a focus on High-Contrast**, utilizing a deep cinematic dark mode to create a sense of focused immersion. 

The brand personality is aggressive yet controlled, evoking a "stealth-mode" atmosphere. Visual interest is generated through high-intensity color accents against an ultra-dark canvas, utilizing subtle ambient glows to represent data flow and connectivity. The interface remains utilitarian, avoiding unnecessary decoration in favor of clear information hierarchy and rapid interaction patterns.

## Colors

The palette is anchored by the signature **Kinetic Red**, a high-chroma red used exclusively for primary actions and active states. 

- **Backgrounds:** A deep, near-black (#0A0A0A) provides the foundation for maximum contrast.
- **Surfaces:** Elevated components use a cool, dark charcoal (#1F2020) to maintain depth without sacrificing the "void" aesthetic.
- **Functional Colors:** Success states utilize a vibrant mint green to contrast sharply against the red and dark grey tones.
- **Accents:** Borders and outlines use a muted, warm-toned variant (#5D3F3B) applied at 10% opacity to provide structure without visual clutter.

## Typography

This design system uses a combination of **Sora** for headlines to provide a modern, geometric tech feel, and **Hanken Grotesk** for functional text to ensure clarity and professional precision.

- **Headlines:** Use Bold Sora with tight tracking to emphasize impact.
- **Hierarchy:** Secondary text and descriptions are consistently rendered at 60% opacity to ensure the primary information remains the focal point.
- **Capsule Logic:** Buttons and Section Titles use increased letter-spacing (tracking) and uppercase styling to evoke a technical, dashboard-style interface.

## Layout & Spacing

The layout follows a **fluid grid system** with rigid 24px horizontal margins for mobile and tablet views. Content is organized in vertical stacks with consistent 16px or 24px gaps to maintain a breathable but structured appearance.

For desktop layouts, a 12-column grid is used with a maximum content width of 1200px. Component spacing should always follow a 4px base unit to ensure alignment with the technical, "engineered" aesthetic of the brand.

## Elevation & Depth

This design system eschews traditional shadows in favor of **Tonal Layering** and **Atmospheric Blurs**.

- **Surface Levels:** Depth is created by placing #1F2020 (Surface) containers on the #0A0A0A (Background).
- **Ambient Glow:** Primary interactive elements or active connection states may feature an under-glow using Kinetic Red (#E2231A) at 5% opacity with an 80px Gaussian blur. This creates a "powered-on" feeling without breaking the flat aesthetic.
- **Borders:** Containers use a subtle 1px border of #5D3F3B at 10% opacity to define edges against the dark background.

## Shapes

The shape language balances aggressive precision with accessibility.

- **Standard Containers:** Use a 16px (1rem) corner radius for cards and larger UI blocks.
- **Interactive Elements:** Buttons and tags use a full "capsule" radius (rounded-xl or pill-shaped) to distinguish them as touchable, dynamic objects within the rigid layout.
- **Iconography:** Should follow a medium-stroke weight with slightly rounded terminals to match the font geometry.

## Components

### Buttons
- **Primary:** Full-width capsule buttons. Background: Kinetic Red (#E2231A), Text: #FFFAFF (Bold, 2px tracking).
- **Secondary:** Transparent background with a 1px border (#5D3F3B at 10%) or a subtle grey tint.

### Cards
- **Standard:** Background #1F2020 with 16px corner radius. Border: #5D3F3B at 10% opacity. Inner padding: 20px - 24px.

### Inputs & Toggles
- **Input Fields:** Darker surface tint than cards, 8px radius, with Kinetic Red used only for the cursor or focus state underline.
- **Toggles:** Track should be a dark neutral; the "thumb" or "active" state must use Kinetic Red.

### Indicators
- **Page Dots:** Active dot uses Kinetic Red (#E2231A). Inactive dots use Secondary (#C8C6C5) at 20% opacity.
- **Status Indicators:** A small circular dot using Success (#4ADE80) for "Connected" states and Kinetic Red for "Disconnected" or "Alert" states.

### Lists
- Items separated by thin dividers using the Outline Variant (#5D3F3B at 10%). Icons within lists should use the Secondary color at 60% opacity unless they are active.