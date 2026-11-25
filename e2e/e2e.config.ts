import { mobile } from '@e2e-dev/mobile';
import type { E2EConfig } from 'e2e';
import { bundleId, launchArguments } from './ios-app.ts';

export default {
  tests: ['tests/ios/**/*.e2e.ts'],
  workers: 1,
  retries: 0,
  targets: [{
    name: 'ios',
    engine: mobile({ platform: 'ios', device: process.env.IOS_DESTINATION }),
    app: { bundleId, launchArguments },
  }],
} satisfies E2EConfig;
