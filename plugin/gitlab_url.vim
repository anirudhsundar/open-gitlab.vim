if exists('g:loaded_gitlab_url')
  finish
endif
let g:loaded_gitlab_url = 1

command! -range GitLabURL call gitlab_url#open([<line1>, <line2>])
