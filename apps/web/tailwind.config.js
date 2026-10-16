import animate from "tailwindcss-animate"
import plugin from "tailwindcss/plugin"

/**
 * Layout classes of the public shop. Registered as components (not plain CSS) so they beat the
 * preflight reset on <ul>/<p> but still lose to a utility on the same element (sm:px-0, sm:grid).
 */
const shopLayout = plugin(({ addComponents }) => {
  addComponents({
    // One page width for the whole shop: fluid gutters, content capped at 1440px.
    ".shop-container": {
      width: "100%",
      maxWidth: "1440px",
      marginLeft: "auto",
      marginRight: "auto",
      paddingLeft: "1rem",
      paddingRight: "1rem",
      "@media (min-width: 640px)": { paddingLeft: "1.5rem", paddingRight: "1.5rem" },
      "@media (min-width: 1024px)": { paddingLeft: "2.5rem", paddingRight: "2.5rem" },
    },
    // A horizontal snap row on phones (categories, chips); sections switch it to a grid from sm up.
    ".shop-scroll-row": {
      display: "flex",
      gap: "0.75rem",
      overflowX: "auto",
      overscrollBehaviorX: "contain",
      scrollSnapType: "x mandatory",
      paddingBottom: "0.5rem",
      scrollbarWidth: "none",
      "&::-webkit-scrollbar": { display: "none" },
    },
  })
})

/** @type {import('tailwindcss').Config} */
const config = {
  darkMode: ["class"],
  safelist: ["dark"],
  prefix: "",

  content: [
    './src/**/*.{ts,vue,html}',
  ],

  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
          subb: "hsl(var(--primary-subb))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        sidebar: {
          DEFAULT: "hsl(var(--sidebar-background))",
          foreground: "hsl(var(--sidebar-foreground))",
          primary: "hsl(var(--sidebar-primary))",
          "primary-foreground": "hsl(var(--sidebar-primary-foreground))",
          accent: "hsl(var(--sidebar-accent))",
          "accent-foreground": "hsl(var(--sidebar-accent-foreground))",
          border: "hsl(var(--sidebar-border))",
          ring: "hsl(var(--sidebar-ring))",
        },
        brand: {
          DEFAULT: "hsl(var(--brand))",
          soft: "hsl(var(--brand-soft))",
        },
        sage: {
          DEFAULT: "hsl(var(--sage))",
          soft: "hsl(var(--sage-soft))",
        },
        "custom-bg": "#0f0e17",
        "custom-primary": "#ff8906",
        "custom-white": "#eeeee4"
      },
      borderRadius: {
        xl: "calc(var(--radius) + 4px)",
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      boxShadow: {
        card: "var(--shadow-card)",
        lift: "var(--shadow-lift)",
      },
      transitionTimingFunction: {
        "out-quart": "cubic-bezier(0.25, 1, 0.5, 1)",
        pop: "cubic-bezier(0.34, 1.56, 0.64, 1)",
      },
      keyframes: {
        "accordion-down": {
          from: { height: 0 },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: 0 },
        },
        "collapsible-down": {
          from: { height: 0 },
          to: { height: 'var(--radix-collapsible-content-height)' },
        },
        "collapsible-up": {
          from: { height: 'var(--radix-collapsible-content-height)' },
          to: { height: 0 },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
        "collapsible-down": "collapsible-down 0.2s ease-in-out",
        "collapsible-up": "collapsible-up 0.2s ease-in-out",
      },
    },
  },
  plugins: [animate, shopLayout],
}

export default config