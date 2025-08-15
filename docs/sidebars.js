/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */

// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  // By default, Docusaurus generates a sidebar from the docs folder structure
  tutorialSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Getting Started',
      items: [
        'getting-started/installation',
        'getting-started/quick-start',
        'getting-started/basic-concepts',
      ],
    },
    {
      type: 'category',
      label: 'Resilience Strategies',
      items: [
        'strategies/overview',
        'strategies/retry',
        'strategies/circuit-breaker',
        'strategies/timeout',
        'strategies/fallback',
        'strategies/hedging',
        'strategies/rate-limiter',
      ],
    },
    {
      type: 'category',
      label: 'Advanced Topics',
      items: [
        'advanced/combining-strategies',
        'advanced/custom-strategies',
        'advanced/monitoring',
        'advanced/testing',
      ],
    },
    {
      type: 'category',
      label: 'API Reference',
      items: [
        'api/resilience-pipeline',
        'api/resilience-pipeline-builder',
        'api/resilience-context',
        'api/outcome',
        'api/retry-strategy',
        'api/circuit-breaker-strategy',
        'api/timeout-strategy',
        'api/fallback-strategy',
        'api/hedging-strategy',
        'api/rate-limiter-strategy',
      ],
    },
    {
      type: 'category',
      label: 'Examples',
      items: [
        'examples/http-client',
      ],
    },
  ],
};

export default sidebars;
