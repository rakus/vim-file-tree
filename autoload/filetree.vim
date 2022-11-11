"
" FILE: filetree.vim
"
" CREATED: 2019-10-27
"

scriptencoding utf-8

" holds the directory tree.
" Entry:
" {
"    Display:     name of the file/dir (w/o path)
"    Childs:      if dir_read: Content of dir
"    Open:        if type == 'dir': Is the content displayed? (0/1)
"    Icon:        Icon to prepend to entry. Either all (but dirs) or none
"                 should have icons
"    dir_read:    if type == 'dir': Is the content read? (0/1)
"    path:        fully qualified name
"    parent:      fully qualified name of parent dir
"    type:        type (file, dir, ... see getftype({fname}) )
"    link:        Is this a symlink? If 1: link is type of target
"    link_target: If link: fully qualified name of target
"    flags:       OR-Expr of: 1 = hidden, 2 = backup file
" }
let s:DirTree = []
let s:ShowHidden = get(g:, 'Tree_ShowHiddenFiles', 1)
let s:ShowBackup = get(g:, 'Tree_ShowBackupFiles', 0)


let s:ICON_LINK       = "\u21d2"
" normal file: 🗎 (DOCUMENT)
let s:ICON_FILE       = "\U1F5CE"
" other stuff: ☢ (RADIOACTIVE SIGN)
let s:ICON_OTHER      = "\u2622"

function! filetree#Tree(...)

    let s:DirTree = s:ReadDir(fnamemodify('.', ':p'))

    let s:DirTree.Open = v:true

    " no title here
    "let entry_list = s:DirTree2EntryList(s:DirTree)

    let popup = selector#Selector('Tree', [ s:DirTree ], function("s:TreeCallback"), #{
                \ type: "popup",
                \ position: g:selector#POPUP_TOP_LEFT,
                \ height: 100,
                \ height_flex: v:false,
                \ select_close: v:false,
                \ tree_events: v:true,
                \ mappings: [
                \ #{ key: 'o', item: 1, help: 'open file without closing popup'},
                \ #{ key: 's', item: 1, help: 'split open file without closing popup'},
                \ #{ key: 'v', item: 1, help: 'vertical split open file without closing popup'},
                \ #{ key: 'i', item: 1, help: 'show file details'},
                \ #{ key: 'I', item: 0, help: 'debug entry info'},
                \ #{ key: 'P', item: 0, help: 'open preference dialog'},
                \ #{ key: 'U', item: 0, help: 'set root one level up'},
                \ #{ key: 'R', item: 1, help: 'set current dir as root'},
                \ #{ key: 'C', item: 1, help: 'read entire dir recursive'},
                \ #{ key: '<F2>', item: 0, help: 'hide'},
                \ ]})

    "highlight TreeDir  ctermfg=darkblue guifg=darkblue
    highlight default link TreeDir  Comment

    call matchadd('TreeDir', "[\u25B8\u25BE] .*", 10, -1, {'window': popup})

    return popup
endfunction

function! s:TreeCallback(id, user_data, key, item)
    echo "key: " . a:key

    if a:key == "<EXPAND>"
        " read content if needed
        let ndir = s:ReadDir(a:item.path)
        call extend(a:item, ndir)
        return g:selector#CB_RC_OK
    elseif a:key == "<COLLAPSE>"
        " do nothing
        return g:selector#CB_RC_OK
    elseif a:key == 'C'
        let ndir = s:ReadDir(a:item.path, v:true)
        call extend(a:item, ndir)
        return g:selector#CB_RC_OK
    elseif a:key == 'i'
        call s:DetailsPopup(a:item)
        return g:selector#CB_RC_OK
    elseif a:key == 'I'
        call s:DbgPopup(a:id, a:item)
        return g:selector#CB_RC_OK
    elseif a:key == 'P'
        call s:PreferencePopup(a:id)
        return g:selector#CB_RC_OK
    elseif a:key == 'U'
        call s:RootUp()
        call s:UpdateContent(a:id)
        call win_execute(a:id, "1")
        call execute("cd " . fnameescape(s:DirTree.path))
        return g:selector#CB_RC_OK
    elseif a:key == '<F2>'
        return g:selector#CB_RC_HIDE
    elseif a:key == 'R'
        if a:item.type == 'dir'
            let s:DirTree = a:item
            let ndir = s:ReadDir(a:item.path)
            call extend(a:item, ndir)
            call execute("cd " . fnameescape(s:DirTree.path))
            let s:DirTree.Open = v:true
            call s:UpdateContent(a:id)
        else
            echo "NoDir: " . a:item.type
        endif
        return g:selector#CB_RC_OK
    endif

    if a:item.type == 'dir'
        if a:key == 'o' || a:key == '<SELECT>'
            let a:item.Open = ! a:item.Open
            if a:item.Open
                let ndir = s:ReadDir(a:item.path)
                call extend(a:item, ndir)
                let a:item.Open = v:true
            endif
        endif

        return g:selector#CB_RC_OK
    else
        let file = a:item.path

        let cmd = "edit"
        if a:key == 's'
            let cmd = "split"
        elseif a:key == 'v'
            let cmd = "vsplit"
        endif

        "exe 'silent ' . cmd . ' '. file
        exe cmd . ' '. file

        "echomsg "KEY: " . a:key
        return a:key == '<SELECT>' ? g:selector#CB_RC_HIDE:g:selector#CB_RC_OK
    endif

endfunction

" Update popup/window content
function! s:UpdateContent(id)
    call selector#UpdateContent(a:id, [ s:DirTree ])
endfunction

function! s:RootUp()
    let ctop = s:DirTree.path
    let ntop = fnamemodify(ctop, ':p:h:h')
    if ctop == ntop
        return
    endif

    let new_tree = s:ReadDir(ntop)
    let new_tree.Open = v:true
    let idx = 0
    while idx < len(new_tree.Childs)
        if new_tree.Childs[idx].path == ctop
            let new_tree.Childs[idx] = s:DirTree
            let new_tree.Childs[idx].Open=v:true
            break
        endif
        let idx+=1
    endwhile

    let s:DirTree = new_tree
endfunction

function! s:CreateEntry(name)
    let fq = fnamemodify(a:name, ':p')
    let fq = substitute(fq, '//*$', '', '')
    let name = fnamemodify(fq, ':t')
    let entry = #{
                \ Display: name,
                \ Hide: v:false,
                \ name: name,
                \ path: fq,
                \ parent: fnamemodify(fq, ':h'),
                \ type: getftype(fq),
                \ link: v:false,
                \ flags: 0,}

    if entry.type == 'link'
        let entry.link = v:true
        let entry.link_target = resolve(entry.path)
        let entry.type = getftype(entry.link_target)
        let entry.Display = name . ' ' . s:ICON_LINK . ' ' . entry.link_target
        let entry.Icon =  s:ICON_LINK
    endif
    if entry.type == 'dir'
        let entry.Childs   = []
        let entry.Open = v:false
        let entry.dir_read = v:false
    elseif entry.type == "file"
        let entry.Icon =  s:ICON_FILE
    else
        let entry.Icon = s:ICON_OTHER
    endif

    call s:FillFileFlags(entry)
    if s:ShowBackup == 0 && s:IsBackup(entry)
        let entry.Hide = v:true
    endif
    if s:ShowHidden == 0 && s:IsHidden(entry)
        let entry.Hide = v:true
    endif
    return entry
endfunction

" Refilter already read entries after s:ShowBackup or s:ShowHidden was
" changed.
function! s:RefilterTree(id)
    call s:RefilterEntry(s:DirTree)
    call s:UpdateContent(a:id)
endfunction

function! s:RefilterEntry(entry)
    if (s:ShowBackup == 0 && s:IsBackup(a:entry))
                \ || (s:ShowHidden == 0 && s:IsHidden(a:entry))
        let a:entry.Hide = v:true
    else
        let a:entry.Hide = v:false
    endif
    if a:entry.type == 'dir'
        for chld in a:entry.Childs
            call s:RefilterEntry(chld)
        endfor
    endif
endfunction

" File flags: hidden file, backup file ?
function! s:FillFileFlags(entry)
    let flag = 0
    if a:entry.Display[0] == '.'
        let flag = flag->or(0b0001)
    endif
    if a:entry.Display =~ '.*\~$' || a:entry.Display =~ '.*\.bak'
        let flag = flag->or(0b0010)
    endif
    let a:entry.flag = flag
endfunction

function! s:IsHidden(entry)
    return a:entry.flag->and(0b0001)
endfunction

function! s:IsBackup(entry)
    return a:entry.flag->and(0b0010)
endfunction

function! s:ReadDir(dir_name, recursive=v:false)
    let dir = fnamemodify(a:dir_name, ':p')

    let entry = s:CreateEntry(dir)
    "let entry.Open = v:true

    return s:ReadDirEntry(entry, a:recursive)
endfunction

function! s:ReadDirEntry(dir_entry, recursive=v:false)
    let list = glob(substitute(a:dir_entry.path, '//*$', '', '') . '/{.,}*', 1, 1)
    let result = []

    " filter out  '*/./' and '*/../' entries
    " create entry structs for all others
    if !a:dir_entry.dir_read || a:dir_entry.Open == false
        let a:dir_entry.Childs = map(filter(list, {i,v -> v !~ '.*/\.\.\?/\?$' }), {i,v -> s:CreateEntry(v)})
        let a:dir_entry.dir_read = v:true
    endif

    if a:recursive
        for entry in a:dir_entry.Childs
            if entry.type == 'dir'
                call s:ReadDirEntry(entry, v:true)
            endif
        endfor
    endif

    return a:dir_entry
endfunction

" popup filter to close popup on any key
function! s:CloseFilter(id, key)
    call popup_close(a:id)
    return 1
endfunction

" get dir content info for DetailsPopup
function! s:GetDirInfo(dir)
    let list = glob(a:dir . '/{.,}*', 1, 1)
    let fc = 0
    let dc = 0
    for e in list
        if e =~ '.*/$'
            let dc+=1
        else
            let fc+=1
        endif
    endfor
    " -2 to ignore './' and '../'
    return fc . ' files, ' . (dc -2) . ' subdirs'
endfunction

" popup to display file/dir details
function! s:DetailsPopup(entry)
    let info = []
    call add(info, "Name: " . a:entry.Display)
    call add(info, "Dir:  " . a:entry.parent)
    call add(info, "Type: " . (a:entry.link?'link to ':'') . a:entry.type)
    call add(info, "Perm: " . getfperm(a:entry.path))
    if a:entry.type == 'dir'
        call add(info, "Size: " . s:GetDirInfo(a:entry.path))
    else
        call add(info, "Size: " . getfsize(a:entry.path))
    endif
    call add(info, "Date: " . strftime('%Y-%m-%d %H:%M:%S', getftime(a:entry.path)))
    if a:entry.type != 'dir' && executable('file')
        call add(info, systemlist("file -bz '" . a:entry.path . "'")[0])
    endif

    call popup_dialog(info,  #{
                \ title: "[Details]",
                \ zindex:400,
                \ filter: function('s:CloseFilter'),
                \ highlight: 'WarningMsg'})
endfunction

" Debug popup to display the current entry
function! s:DbgPopup(id, entry)
    let dbg = a:entry

    let info = []
    call add(info, "Name:     " . dbg.name)
    call add(info, "Path:     " . dbg.path)
    call add(info, "Parent:   " . dbg.parent)
    call add(info, "Type:     " . dbg.type)
    call add(info, "Link:     " . dbg.link)
    call add(info, "Flags:    " . printf("0b%04b", dbg.flag))
    if dbg.type == 'dir'
        call add(info, "dir_read: " . dbg.dir_read)
        call add(info, "Open:     " . dbg.Open)
        call add(info, "Childs:   " . len(dbg.Childs))
    endif

    " let opts = popup_getoptions(a:id)
    " for k in keys(opts)
    "     call add(info, printf("%-10s : %s", k, opts[k]))
    " endfor

    " call add(info, "=======")

    " let pos =popup_getpos(a:id)
    " for k in keys(pos)
    "     call add(info, printf("%-10s : %s", k, pos[k]))
    " endfor


    call popup_dialog(info,  #{
                \ title: "[Debug]",
                \ zindex:400,
                \ filter: function('s:CloseFilter'),
                \ highlight: 'WarningMsg'})
endfunction

function! s:PreferenceFilter(id, key)
    let update = v:false
    if a:key == 'b'
        let s:ShowBackup = ! s:ShowBackup
        let update = v:true
    elseif  a:key == 'h'
        let s:ShowHidden = ! s:ShowHidden
        let update = v:true
    elseif a:key == 'x'
        call popup_close(a:id)
    endif
    if update
        call s:RefilterTree(getwinvar(a:id, 'parent_popup'))
        call popup_settext(a:id, s:GetPreferenceContent())
    endif
    return 1
endfunction

function! s:GetPreferenceContent()
    let info = []
    if s:ShowBackup
        call add(info, "b       Hide backup files")
    else
        call add(info, "b       Show backup files")
    endif
    if s:ShowHidden
        call add(info, "h       Hide hidden files")
    else
        call add(info, "h       Show hidden files")
    endif
    call add(info, "x       close this menu")

    return info
endfunction


function! s:PreferencePopup(id)

    let popup = popup_dialog(s:GetPreferenceContent(),  #{
                \ title:'[Tree Preferences]',
                \ zindex:400,
                \ filter: function('s:PreferenceFilter'),
                \ highlight: 'WarningMsg'})

    call setwinvar(popup, "parent_popup", a:id)
endfunction

"    vim:tw=75 et ts=4 sw=4 sr ai comments=\:\" formatoptions=croq
