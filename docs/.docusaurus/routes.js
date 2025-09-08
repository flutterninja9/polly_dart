import React from 'react';
import ComponentCreator from '@docusaurus/ComponentCreator';

export default [
  {
    path: '/__docusaurus/debug',
    component: ComponentCreator('/__docusaurus/debug', '5ff'),
    exact: true
  },
  {
    path: '/__docusaurus/debug/config',
    component: ComponentCreator('/__docusaurus/debug/config', '5ba'),
    exact: true
  },
  {
    path: '/__docusaurus/debug/content',
    component: ComponentCreator('/__docusaurus/debug/content', 'a2b'),
    exact: true
  },
  {
    path: '/__docusaurus/debug/globalData',
    component: ComponentCreator('/__docusaurus/debug/globalData', 'c3c'),
    exact: true
  },
  {
    path: '/__docusaurus/debug/metadata',
    component: ComponentCreator('/__docusaurus/debug/metadata', '156'),
    exact: true
  },
  {
    path: '/__docusaurus/debug/registry',
    component: ComponentCreator('/__docusaurus/debug/registry', '88c'),
    exact: true
  },
  {
    path: '/__docusaurus/debug/routes',
    component: ComponentCreator('/__docusaurus/debug/routes', '000'),
    exact: true
  },
  {
    path: '/blog',
    component: ComponentCreator('/blog', 'b9a'),
    exact: true
  },
  {
    path: '/blog/archive',
    component: ComponentCreator('/blog/archive', '182'),
    exact: true
  },
  {
    path: '/blog/authors',
    component: ComponentCreator('/blog/authors', '0b7'),
    exact: true
  },
  {
    path: '/blog/introducing-polly-dart',
    component: ComponentCreator('/blog/introducing-polly-dart', '56d'),
    exact: true
  },
  {
    path: '/blog/tags',
    component: ComponentCreator('/blog/tags', '287'),
    exact: true
  },
  {
    path: '/blog/tags/announcement',
    component: ComponentCreator('/blog/tags/announcement', '724'),
    exact: true
  },
  {
    path: '/blog/tags/dart',
    component: ComponentCreator('/blog/tags/dart', '223'),
    exact: true
  },
  {
    path: '/blog/tags/flutter',
    component: ComponentCreator('/blog/tags/flutter', '9c3'),
    exact: true
  },
  {
    path: '/blog/tags/reliability',
    component: ComponentCreator('/blog/tags/reliability', '6ff'),
    exact: true
  },
  {
    path: '/blog/tags/resilience',
    component: ComponentCreator('/blog/tags/resilience', 'dbd'),
    exact: true
  },
  {
    path: '/search',
    component: ComponentCreator('/search', '5de'),
    exact: true
  },
  {
    path: '/',
    component: ComponentCreator('/', '0f7'),
    routes: [
      {
        path: '/',
        component: ComponentCreator('/', '1fc'),
        routes: [
          {
            path: '/',
            component: ComponentCreator('/', '8bd'),
            routes: [
              {
                path: '/advanced/combining-strategies',
                component: ComponentCreator('/advanced/combining-strategies', '584'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/advanced/custom-strategies',
                component: ComponentCreator('/advanced/custom-strategies', '543'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/advanced/monitoring',
                component: ComponentCreator('/advanced/monitoring', 'dcc'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/advanced/testing',
                component: ComponentCreator('/advanced/testing', '672'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/cache-strategy',
                component: ComponentCreator('/api/cache-strategy', '529'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/circuit-breaker-strategy',
                component: ComponentCreator('/api/circuit-breaker-strategy', '3d9'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/fallback-strategy',
                component: ComponentCreator('/api/fallback-strategy', '0e2'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/hedging-strategy',
                component: ComponentCreator('/api/hedging-strategy', '0c1'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/outcome',
                component: ComponentCreator('/api/outcome', '308'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/rate-limiter-strategy',
                component: ComponentCreator('/api/rate-limiter-strategy', 'dd0'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/resilience-context',
                component: ComponentCreator('/api/resilience-context', '51b'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/resilience-pipeline',
                component: ComponentCreator('/api/resilience-pipeline', 'd38'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/resilience-pipeline-builder',
                component: ComponentCreator('/api/resilience-pipeline-builder', '88f'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/retry-strategy',
                component: ComponentCreator('/api/retry-strategy', '641'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/api/timeout-strategy',
                component: ComponentCreator('/api/timeout-strategy', 'b4e'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/examples/cache',
                component: ComponentCreator('/examples/cache', '6b8'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/examples/http-client',
                component: ComponentCreator('/examples/http-client', 'af4'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/getting-started/basic-concepts',
                component: ComponentCreator('/getting-started/basic-concepts', 'cfc'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/getting-started/installation',
                component: ComponentCreator('/getting-started/installation', '654'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/getting-started/quick-start',
                component: ComponentCreator('/getting-started/quick-start', 'fd2'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/intro',
                component: ComponentCreator('/intro', '9fa'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/strategies/cache',
                component: ComponentCreator('/strategies/cache', 'b71'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/strategies/circuit-breaker',
                component: ComponentCreator('/strategies/circuit-breaker', '316'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/strategies/fallback',
                component: ComponentCreator('/strategies/fallback', '4ea'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/strategies/hedging',
                component: ComponentCreator('/strategies/hedging', 'f34'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/strategies/overview',
                component: ComponentCreator('/strategies/overview', '421'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/strategies/rate-limiter',
                component: ComponentCreator('/strategies/rate-limiter', '6f9'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/strategies/retry',
                component: ComponentCreator('/strategies/retry', 'e26'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/strategies/timeout',
                component: ComponentCreator('/strategies/timeout', 'ab9'),
                exact: true,
                sidebar: "tutorialSidebar"
              },
              {
                path: '/',
                component: ComponentCreator('/', 'c48'),
                exact: true
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
