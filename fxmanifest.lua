fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'cobalt_police'
author 'Project Cobalt'
description 'Police: restraints, stations, clamps, tape, jail, dispatch and the MDT'
version '1.0.0'

dependencies {
    'cobalt_mysql',
    'ox_lib',
    'ox_target',
    'cobalt_core',
    'cobalt_inventory',
}

shared_script '@ox_lib/init.lua'

ox_libs { 'locale' }

client_script 'client/init.lua'

server_scripts {
    '@cobalt_mysql/lib/MySQL.lua',
    '@cobalt_core/server/migrationgate.lua',
    'server/init.lua',
}

ui_page '_nui/build/index.html'

files {
    'config.lua',
    'client/*.lua',
    'locales/*.json',
    '_nui/build/index.html',
    '_nui/build/**/*',
    'stream/clamp.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/clamp.ytyp'
