if exists('g:loaded_particle') 
    finish 
endif " prevent loading file twice
let g:loaded_particle = 1

command! Particle lua require'particle'.particle()

