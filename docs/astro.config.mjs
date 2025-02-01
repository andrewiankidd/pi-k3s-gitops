import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
    site: 'https://andrewiankidd.github.io/pi-k3s-gitops',
	base: '/pi-k3s-gitops',
    server: {
        host: true,
    },
    redirects: {
        // match doesn't include base, but destination does
        '/guides/netboot/0-index': {
          status: 307,
          destination: '/pi-k3s-gitops/guides/netboot/index',
        },
    },
    integrations: [
		starlight({
			title: 'pi-k3s-gitops',
			social: {
				github: 'https://github.com/andrewiankidd/pi-k3s-gitops',
			},
			sidebar: [
                {
					label: 'About',
					autogenerate: { directory: 'about' },
				},
				{
					label: 'Guides',
                    items: [
                        {
                            label: 'Netboot',
                            autogenerate: { directory: 'guides/Netboot' },
                        },
                        {
                            label: 'Declarative Cluster',
                            autogenerate: { directory: 'guides/Declarative Cluster' },
                        },
                        {
                            label: 'Other',
                            autogenerate: { directory: 'guides/Other' },
                        },
                    ]
				},
				{
					label: 'Reference',
					autogenerate: { directory: 'reference' },
				},
			],
		}),
	],
});
