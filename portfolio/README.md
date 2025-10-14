UX Portfolio (Static)
=====================

Pages
- Home: index.html
- About: about.html
- Portfolio: work.html
- Contact: contact.html

Customization
- Brand name: header brand text in each page.
- Accent color (teal): adjust --accent and --accent-700 in assets/styles.css.
- Social links: update footer links in each page (LinkedIn/GitHub).
- Resume: place your PDF at portfolio/assets/resume.pdf and the Download link will work.
- Images: add cover images in portfolio/assets/images and keep filenames used in pages (or update paths).

Contact form
- The form posts to Formspree. Replace action="https://formspree.io/f/your-id" in contact.html with your Formspree form endpoint.
- Alternatively, replace the form action with "mailto:you@example.com" for a simple email client fallback.

Animations
- Scroll reveal is handled by IntersectionObserver (assets/main.js). Add class "reveal" to any element you want to animate on entry.

Deployment
- This is a static site. Host on GitHub Pages, Netlify, or any static hosting.
- If you want it at the root of your domain, move the contents of the "portfolio" folder to the web root.

Fonts
- Uses Inter via Google Fonts. You can swap for Lato by updating the <link> and font-family in CSS.