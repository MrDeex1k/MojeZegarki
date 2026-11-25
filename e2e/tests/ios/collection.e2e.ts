import { beforeEach, test } from '@e2e-dev/mobile';
import { expect } from 'e2e';
import { bundleId, launchArguments } from '../../ios-app.ts';

beforeEach(async ({ device, screen }) => {
  await device.openApp(bundleId, {
    relaunch: true,
    launchArguments: [...launchArguments, '--reset-test-store'],
  });
  await expect(screen.getByTestId('collection.addFirst')).toBeVisible({ timeout: 15_000 });
});

test('saves and edits a watch and keeps the edit after a restart', async ({ app, screen }) => {
  await screen.getByTestId('collection.addFirst').tap();
  await screen.getByTestId('editor.brand').fill('Seiko');
  await screen.getByTestId('editor.model').fill('Prospex');
  await screen.getByTestId('editor.save').tap();

  await screen.getByText('Prospex', { exact: true }).tap();
  await screen.getByTestId('detail.edit').tap();
  await screen.getByTestId('editor.model').fill('Alpinist');
  await screen.getByTestId('editor.save').tap();
  await expect(screen.getByTestId('detail.model')).toHaveText('Seiko Alpinist');

  await app.restart();
  await expect(screen.getByText('Alpinist', { exact: true })).toBeVisible();
  await expect(screen.getByText('Prospex', { exact: true })).toHaveCount(0);
});

test('moves a wish to the collection and persists its wear entry', async ({ app, screen }) => {
  const tabBar = screen.getByRole('tablist', { name: 'Tab Bar', exact: true });
  // iOS accessibility snapshots expose the same tab as a tab or a button.
  const tab = (name: string) => tabBar.getByRole('tab', { name, exact: true })
    .or(tabBar.getByRole('button', { name, exact: true }));

  await tab('Wishlist').tap();
  await screen.getByTestId('wish.add').tap();
  await screen.getByTestId('wish.brand').fill('Casio');
  await screen.getByTestId('wish.model').fill('G-Shock');
  await screen.getByTestId('wish.save').tap();

  await screen.getByTestId(/^wish\.quickMove\./).tap();
  await expect(screen.getByText('Your next watch', { exact: true })).toBeVisible();
  await screen.getByRole('button', { name: 'Show collection', exact: true }).tap();
  await screen.getByText('G-Shock', { exact: true }).tap();
  await screen.getByTestId('wear.today').tap();

  await app.restart();
  await expect(screen.getByTestId('collection.add')).toBeVisible({ timeout: 15_000 });
  await tab('Wearing').tap();
  await expect(screen.getByText('1 day worn', { exact: true })).toBeVisible();
});
