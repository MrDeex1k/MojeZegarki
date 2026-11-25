import { expect, test } from '@playwright/test';

test('submits a browser form and displays its result', async ({ page }) => {
  const fixtureUrl = 'http://watch-form.test/';
  await page.route(fixtureUrl, (route) => route.fulfill({
    contentType: 'text/html',
    body: `
      <!doctype html>
      <html lang="en">
        <head><title>Watch form</title></head>
        <body>
          <form>
            <label>Model <input name="model" required></label>
            <button>Save</button>
          </form>
          <output role="status"></output>
          <script>
            document.querySelector('form').addEventListener('submit', (event) => {
              event.preventDefault();
              const model = new FormData(event.currentTarget).get('model');
              document.querySelector('output').textContent = 'Saved ' + model;
            });
          </script>
        </body>
      </html>
    `,
  }));
  await page.goto(fixtureUrl);
  await page.getByRole('textbox', { name: 'Model' }).fill('Alpinist');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByRole('status')).toHaveText('Saved Alpinist');
});
