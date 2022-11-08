"
" FILE: treePlugin.vim
"
" CREATED: 2019-10-27
"

command! -nargs=* Tree call tree#Tree(<f-args>)

let s:TreePopup = -1

function! s:OpenTree()

    if s:TreePopup < 0 || empty(popup_getpos(s:TreePopup))
        let s:TreePopup = tree#Tree()
    else
        call selector#UnHide(s:TreePopup)
    endif
endfunction

nnoremap <F2> :call <SID>OpenTree()<cr>

"    vim:tw=75 et ts=4 sw=4 sr ai comments=\:\" formatoptions=croq
