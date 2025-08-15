import React from 'react';
import ComponentCreator from '@docusaurus/ComponentCreator';

export default [
  {
    path: '/polly_dart/__docusaurus/debug',
    component: ComponentCreator('/polly_dart/__docusaurus/debug', '4e5'),
    exact: true
  },
  {
    path: '/polly_dart/__docusaurus/debug/config',
    component: ComponentCreator('/polly_dart/__docusaurus/debug/config', '1b3'),
    exact: true
  },
  {
    path: '/polly_dart/__docusaurus/debug/content',
    component: ComponentCreator('/polly_dart/__docusaurus/debug/content', '5e5'),
    exact: true
  },
  {
    path: '/polly_dart/__docusaurus/debug/globalData',
    component: ComponentCreator('/polly_dart/__docusaurus/debug/globalData', '940'),
    exact: true
  },
  {
    path: '/polly_dart/__docusaurus/debug/metadata',
    component: ComponentCreator('/polly_dart/__docusaurus/debug/metadata', 'fcf'),
    exact: true
  },
  {
    path: '/polly_dart/__docusaurus/debug/registry',
    component: ComponentCreator('/polly_dart/__docusaurus/debug/registry', '89d'),
    exact: true
  },
  {
    path: '/polly_dart/__docusaurus/debug/routes',
    component: ComponentCreator('/polly_dart/__docusaurus/debug/routes', '895'),
    exact: true
  },
  {
    path: '/polly_dart/blog',
    component: ComponentCreator('/polly_dart/blog', '08c'),
    exact: true
  },
  {
    path: '/polly_dart/blog/archive',
    component: ComponentCreator('/polly_dart/blog/archive', '67d'),
    exact: true
  },
  {
    path: '/polly_dart/blog/authors',
    component: ComponentCreator('/polly_dart/blog/authors', '9ef'),
    exact: true
  },
  {
    path: '/polly_dart/blog/introducing-polly-dart',
    component: ComponentCreator('/polly_dart/blog/introducing-polly-dart', '526'),
    exact: true
  },
  {
    path: '/polly_dart/blog/tags',
    component: ComponentCreator('/polly_dart/blog/tags', '550'),
    exact: true
  },
  {
    path: '/polly_dart/blog/tags/announcement',
    component: ComponentCreator('/polly_dart/blog/tags/announcement', 'f48'),
    exact: true
  },
  {
    path: '/polly_dart/blog/tags/dart',
    component: ComponentCreator('/polly_dart/blog/tags/dart', 'c21'),
    exact: true
  },
  {
    path: '/polly_dart/blog/tags/flutter',
    component: ComponentCreator('/polly_dart/blog/tags/flutter', 'bb8'),
    exact: true
  },
  {
    path: '/polly_dart/blog/tags/reliability',
    component: ComponentCreator('/polly_dart/blog/tags/reliability', '560'),
    exact: true
  },
  {
    path: '/polly_dart/blog/tags/resilience',
    component: ComponentCreator('/polly_dart/blog/tags/resilience', '18b'),
    exact: true
  },
  {
    path: '/polly_dart/search',
    component: ComponentCreator('/polly_dart/search', '0f6'),
    exact: true
  },
  {
    path: '/polly_dart/docs',
    component: ComponentCreator('/polly_dart/docs', 'd97'),
    routes: [
      {
        path: '/polly_dart/docs',
        component: ComponentCreator('/polly_dart/docs', '3ab'),
        routes: [
          {
            path: '/polly_dart/docs',
            component: ComponentCreator('/polly_dart/docs', '54c'),
            routes: [
              {
                path: '/polly_dart/docs/',
                component: ComponentCreator('/polly_dart/docs/', '27d'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/advanced/combining-strategies',
                component: ComponentCreator('/polly_dart/docs/advanced/combining-strategies', '1c3'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/advanced/custom-strategies',
                component: ComponentCreator('/polly_dart/docs/advanced/custom-strategies', '035'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/advanced/monitoring',
                component: ComponentCreator('/polly_dart/docs/advanced/monitoring', '87a'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/advanced/testing',
                component: ComponentCreator('/polly_dart/docs/advanced/testing', '7cb'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/api/circuit-breaker-strategy',
                component: ComponentCreator('/polly_dart/docs/api/circuit-breaker-strategy', 'b0f'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/api/fallback-strategy',
                component: ComponentCreator('/polly_dart/docs/api/fallback-strategy', '364'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/api/hedging-strategy',
                component: ComponentCreator('/polly_dart/docs/api/hedging-strategy', '7b7'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/api/outcome',
                component: ComponentCreator('/polly_dart/docs/api/outcome', '58b'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/api/rate-limiter-strategy',
                component: ComponentCreator('/polly_dart/docs/api/rate-limiter-strategy', '51e'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/api/resilience-context',
                component: ComponentCreator('/polly_dart/docs/api/resilience-context', '1fa'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/api/resilience-pipeline',
                component: ComponentCreator('/polly_dart/docs/api/resilience-pipeline', '361'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/api/resilience-pipeline-builder',
                component: ComponentCreator('/polly_dart/docs/api/resilience-pipeline-builder', '5d6'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/api/retry-strategy',
                component: ComponentCreator('/polly_dart/docs/api/retry-strategy', 'b5e'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/api/timeout-strategy',
                component: ComponentCreator('/polly_dart/docs/api/timeout-strategy', '794'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/examples/http-client',
                component: ComponentCreator('/polly_dart/docs/examples/http-client', '203'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/getting-started/basic-concepts',
                component: ComponentCreator('/polly_dart/docs/getting-started/basic-concepts', 'fdc'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/getting-started/installation',
                component: ComponentCreator('/polly_dart/docs/getting-started/installation', '82b'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/getting-started/quick-start',
                component: ComponentCreator('/polly_dart/docs/getting-started/quick-start', 'ec6'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/strategies/circuit-breaker',
                component: ComponentCreator('/polly_dart/docs/strategies/circuit-breaker', '9f1'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/strategies/fallback',
                component: ComponentCreator('/polly_dart/docs/strategies/fallback', 'daa'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/strategies/hedging',
                component: ComponentCreator('/polly_dart/docs/strategies/hedging', 'd41'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/strategies/overview',
                component: ComponentCreator('/polly_dart/docs/strategies/overview', 'c19'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/strategies/rate-limiter',
                component: ComponentCreator('/polly_dart/docs/strategies/rate-limiter', 'dab'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/strategies/retry',
                component: ComponentCreator('/polly_dart/docs/strategies/retry', '37c'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/polly_dart/docs/strategies/timeout',
                component: ComponentCreator('/polly_dart/docs/strategies/timeout', '0a2'),
                exact: true,
                sidebar: "tutorialSidebar"
              }
            ]
          }
        ]
      }
    ]
  },
  {
    path: '*',
    component: ComponentCreator('*'),
  },
];
