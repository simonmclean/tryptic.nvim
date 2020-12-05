if exists("g:threeway_ftplugin")
	finish
endif
let g:threeway_ftplugin = 1

syntax match PathExcludingFileName /^\/.*\/.\@=/ conceal
