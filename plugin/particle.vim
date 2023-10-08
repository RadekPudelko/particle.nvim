" Put description here!!!
" Last Change:  2020 Jan 31
" Maintainer:   Rafał Camlet <raf.camlet@gmail.com>
" License:      GNU General Public License v3.0

if exists('g:loaded_whid') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo
set cpo&vim

hi def link ParticleHeader      Number
hi def link ParticleSubHeader   Identifier
" hi ParticleCursorLine ctermbg=238 cterm=none

command! Particle lua require'particle'.particle()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_whid = 1
