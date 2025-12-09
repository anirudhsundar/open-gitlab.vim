function! s:git(args) abort
  let l:cmd = ['git']
  call extend(l:cmd, a:args)
  let l:out = systemlist(l:cmd)
  if v:shell_error != 0
    throw printf('GitLabURL: git command failed: %s', join(a:args, ' '))
  endif
  return l:out
endfunction

function! s:remote_url() abort
  let l:remote = ''
  try
    let l:upstream = s:git(['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}'])
    if !empty(l:upstream)
      let l:pieces = split(l:upstream[0], '/')
      if len(l:pieces) >= 1
        let l:remote = l:pieces[0]
      endif
    endif
  catch /.*/
    " fall back to origin when there is no upstream
  endtry
  if empty(l:remote)
    let l:remote = 'origin'
  endif
  try
    let l:url = s:git(['remote', 'get-url', l:remote])
  catch /.*/
    throw 'GitLabURL: unable to determine remote URL'
  endtry
  if empty(l:url)
    throw 'GitLabURL: remote URL is empty'
  endif
  return l:url[0]
endfunction

function! s:normalize_remote(url) abort
  let l:raw = a:url
  let l:url = substitute(a:url, '\s\+$', '', '')
  let l:scheme = 'https'
  let l:host = ''
  let l:path = ''

  " HTTPS / HTTP (e.g. https://gitlab.com/group/project.git)
  if l:url =~? '^\%(https\|http\)://'
    let l:m = matchlist(l:url, '^\(https\|http\)://\([^/]\+\)/\?\(.*\)$')
    if empty(l:m) || empty(l:m[2]) || empty(l:m[3])
      throw printf('GitLabURL: remote URL does not include host and repo path: %s', l:raw)
    endif
    let l:scheme = l:m[1]
    let l:host = l:m[2]
    let l:path = l:m[3]
  else
    " Strip ssh:// if present
    if l:url =~? '^ssh://'
      let l:url = l:url[6:]
    endif

    " Strip optional user@
    let l:url_wo_user = substitute(l:url, '^[^@]\+@', '', '')

    " Now expect: host[:port][/:]path
    let l:sep = match(l:url_wo_user, '[:/]')
    if l:sep < 0
      throw printf('GitLabURL: remote URL does not contain repo path: %s', l:raw)
    endif

    let l:host = strpart(l:url_wo_user, 0, l:sep)
    let l:path = strpart(l:url_wo_user, l:sep + 1)
  endif

  if l:path =~ '\.git$'
    let l:path = l:path[:-5]
  endif

  let l:path = substitute(l:path, '^/', '', '')

  if empty(l:host) || empty(l:path)
    throw printf('GitLabURL: remote URL does not include host and repo path: %s', l:raw)
  endif

  return printf('%s://%s/%s', l:scheme, l:host, l:path)
endfunction

function! s:encode_segment(segment) abort
  let l:result = ''
  for l:ch in split(a:segment, '\zs')
    let l:nr = char2nr(l:ch)
    if l:ch =~# '[A-Za-z0-9._~-]'
      let l:result .= l:ch
    else
      let l:result .= printf('%%%02X', l:nr)
    endif
  endfor
  return l:result
endfunction

function! s:encode_path(value) abort
  let l:segments = split(a:value, '/', 1)
  call map(l:segments, 's:encode_segment(v:val)')
  return join(l:segments, '/')
endfunction

function! s:repo_ref() abort
  let l:branch = []
  try
    let l:branch = s:git(['symbolic-ref', '--quiet', '--short', 'HEAD'])
  catch /.*/
    " detached HEAD
  endtry
  if !empty(l:branch) && !empty(l:branch[0])
    return l:branch[0]
  endif
  let l:commit = s:git(['rev-parse', 'HEAD'])
  return l:commit[0]
endfunction

function! s:repo_relative_path() abort
  let l:absolute = expand('%:p')
  if empty(l:absolute)
    throw 'GitLabURL: current buffer is not associated with a file'
  endif

  let l:list = systemlist(['git', 'ls-files', '--full-name', l:absolute])
  if v:shell_error == 0 && !empty(l:list)
    return l:list[0]
  endif

  let l:root = s:git(['rev-parse', '--show-toplevel'])[0]
  let l:normalized_root = substitute(l:root, '\\', '/', 'g')
  let l:normalized_file = substitute(l:absolute, '\\', '/', 'g')

  if l:normalized_file[:len(l:normalized_root) - 1] !=# l:normalized_root
    throw 'GitLabURL: file is outside of the repository root'
  endif

  let l:relative = strpart(l:normalized_file, len(l:normalized_root))
  let l:relative = substitute(l:relative, '^/', '', '')

  if empty(l:relative)
    throw 'GitLabURL: unable to compute repository relative path'
  endif

  return l:relative
endfunction

function! s:build_url(range) abort
  let l:firstline = a:range[0]
  let l:lastline = a:range[1]

  let l:remote = s:normalize_remote(s:remote_url())
  let l:ref = s:encode_path(s:repo_ref())
  let l:path = s:encode_path(s:repo_relative_path())

  let l:url = printf('%s/-/blob/%s/%s', l:remote, l:ref, l:path)

  if l:firstline > 0
    if l:lastline <= l:firstline
      let l:url .= '#L' . l:firstline
    else
      let l:url .= printf('#L%d-%d', l:firstline, l:lastline)
    endif
  endif

  return l:url
endfunction

function! gitlab_url#open(range) abort
  try
    let l:url = s:build_url(a:range)
    echo l:url
  catch /.*/
    echohl ErrorMsg
    echomsg v:exception
    echohl None
  endtry
endfunction
