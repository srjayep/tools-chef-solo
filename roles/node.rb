name 'node'
description 'Sets up ruby and common packages'

run_list \
  'recipe[ruby_build]',
  'recipe[ruby]'

default_attributes \
  'ruby_version' => '1.9.3-p194'

