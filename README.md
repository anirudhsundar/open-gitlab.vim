gitlab_url.vim
===============

Generate GitLab URLs for the current buffer and line range directly from Vim.

The `:GitLabURL` command prints a GitLab `blob` URL for the file in the
current buffer, including an anchor to the current line or selected range.

The plugin works with any Git remote that points to a GitLab instance,
handling both SSH and HTTPS remotes.

Example URL shape:

  `https://gitlab.com/group/project/-/blob/main/path/to/file.py#L10-20`


Installation
------------

Using **vim-plug**:

```vim
Plug 'anirudhsundar/open-gitlab.vim'
```

Then run `:PlugInstall`.

Using Vim's built-in package support:

```sh
git clone https://gitlab.com/anirudhsundar/open-gitlab.vim \
  ~/.vim/pack/plugins/start/open-gitlab.vim
```


Usage
-----

- Normal mode, current line:

  ```vim
  :GitLabURL
  ```

- Visual mode, selected range:

  ```vim
  :'<,'>GitLabURL
  ```

In both cases the plugin:

- Detects the repository root using `git rev-parse`.
- Determines the remote (preferring the branch upstream, falling back to
  `origin`).
- Converts common Git URL formats (HTTPS and SSH) into a canonical
  `https://host/group/project` form.
- Uses the current branch name when available, otherwise the current commit.
- Computes the repository-relative path of the current buffer.
- Prints a URL of the form:

  `https://<gitlab-host>/<group>/<project>/-/blob/<ref>/<path>#L<start>-<end>`


Help
----

After installing the plugin, generate help tags once:

```vim
:helptags ~/.vim/pack/plugins/start/open-gitlab.vim/doc
```

Then use:

```vim
:help gitlab_url
```

