# Polly Dart Documentation

This directory contains the complete documentation website for Polly Dart, built with Docusaurus.

## Documentation Structure

- **Getting Started** - Installation, quick start, and basic concepts
- **Resilience Strategies** - Detailed guides for each strategy
- **Advanced Topics** - Complex scenarios and best practices  
- **API Reference** - Complete API documentation
- **Examples** - Real-world usage examples

## Development

### Prerequisites
- Node.js 18.0 or higher
- npm or yarn

### Setup
```bash
cd docs
npm install
```

### Development Server
```bash
npm start
```

### Build
```bash
npm run build
```

### Deployment
The documentation is configured for GitHub Pages deployment:

```bash
npm run deploy
```

## Contributing

When adding new documentation:

1. Follow the existing structure and style
2. Include practical examples
3. Add proper cross-references
4. Test all code examples
5. Update navigation in `sidebars.js`

## Customization

- **Styling**: Edit `src/css/custom.css`
- **Configuration**: Edit `docusaurus.config.js`
- **Navigation**: Edit `sidebars.js`
- **Assets**: Add to `static/img/`
