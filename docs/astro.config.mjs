import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
    site: 'https://andrewiankidd.github.io/pi-k3s-gitops',
	base: '/pi-k3s-gitops',
    integrations: [
		starlight({
			title: 'pi-k3s-gitops',
			social: {
				github: 'https://github.com/andrewiankidd/pi-k3s-gitops',
			},
			sidebar: [
				{
					label: 'Guides',
					autogenerate: { directory: 'guides' },
				},
				{
					label: 'Reference',
					autogenerate: { directory: 'reference' },
				},
			],
		}),
	],
});
