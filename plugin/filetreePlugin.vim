"
" FILE: filetreePlugin.vim
"
" CREATED: 2019-10-27
"

command! -nargs=* FileTree call filetree#Tree(<f-args>)

let s:TreePopup = -1

function! s:OpenTree()

    if s:TreePopup < 0 || empty(popup_getpos(s:TreePopup))
        let s:TreePopup = filetree#Tree()
    else
        call selector#UnHide(s:TreePopup)
    endif
endfunction

nnoremap <F2> :call <SID>OpenTree()<cr>

"    vim:tw=75 et ts=4 sw=4 sr ai comments=\:\" formatoptions=croq
