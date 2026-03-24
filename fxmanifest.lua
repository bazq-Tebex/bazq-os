fx_version 'cerulean'
game 'gta5'

name 'bazq-os'
description 'bazq Object Spawner - Professional building system with advanced placement tools'
author 'bazq'
version '2.3.1'


shared_scripts {
    'shared/config.lua',
    'shared/locales.lua'
}

client_scripts {
    'freecam/utils.lua',
    'freecam/config.lua',
    'freecam/camera.lua',
    'freecam/main.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
    'html/images/*.png',
    'html/*.ttf',
    'objects_config.json'
}

escrow_ignore {
  '**/*.lua',
  '**/*.json',
  'objects_config.json'
}