return {
	name = 'Skugg Supercomm Mod (dev)',   -- remove dev before packaging to sdz
	description = 'A mod to explore time-limited but otherwise unbalanced commander upgrades.',
	shortname = 'skugg-s-c-mod-dev',      -- remove dev before packaging to sdz
	version = 'v6',                       -- increment sometimes (can not overwrite something already uploaded)
	mutator = '1',
	game = '',
	shortGame = '',
	modtype = 1,
	depend = {
		[[rapid://zk:stable]]
	},
}
