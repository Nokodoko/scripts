#this is a file that is sourced by my shell and helps with thins like file navigation/searching our code
#base, and keeping up-to-date with changes to the code base. (WARNING: I am unable to get a working version
#of gitlab used in Brian's git-clone script which effectively will clone capacity's entire repo and 
#everyone using this will likely have a different path to the code base. MODIFY THE PATH TO MATCH YOURS)


function c() {
    cd $1 && ls 
}

#Capacity
alias repo='c ~/capacity/repos/'
alias dev='c ~/capacity/repos/dev/'
alias operations='c ~/capacity/repos/dev/ops/'
alias services='c ~/capacity/repos/dev/services'
alias based='~/capacity/repos/dev/'


#possible refactor with fd to recursively act - <x> directory level(s) to perform pull command1 
#function capRefresh() {
#    for dir in ~/capacity/repos/dev/*/; do
#        cd "$dir"
#         git pull
#         cd ..
#    done
#}

#Please see note below regarding the helper function 'gitup'. If you do not want to make this 
#into your own binary, take the helper function below, and move it above this function block, uncomment it.    
function capRefresh() {
    for dir in ~/capacity/repos/dev/*/; do
        gitup
    done
}

function serv() {
    v ~/capacity/repos/dev/services/$(cd ~/capacity/repos/dev/services && fzf)
}

function ops() {
    v ~/capacity/repos/dev/ops/$(cd ~/capacity/repos/dev/ops && fzf)
}

function cf() {
    v $(fd -d9 -tf yaml ~/capacity/repos/dev/ | fzf)
}

#function ops() {
#    v $(fd -d5 -tf tf ~/capacity/repos/dev/ops | fzf)
#}
#alias apps='c ~/capacity/repos/dev/services/apps/'
function apps() {
    v $(fd -tf yaml -d9 --full-path ~/capacity/repos/dev | fzf)
}
##
##function ops() {
##    v $(fd -tf yaml -d9 --full-path ~/capacity/repos/dev | fzf)
##}
##
##function serv() {
##    v $(fd -tf yaml -d9 --full-path ~/capacity/repos/dev | fzf)
##}
##
##function dev() {
##    v $(fd -tf yaml -d9 --full-path ~/capacity/repos/dev | fzf)
##}
alias bi='c ~/capacity/repos/dev/services/bi/'
alias ai='c ~/capacity/repos/dev/services/ai/'
alias rangers='c ~/capacity/repos/dev/services/dataRangers/'

##Locally I have this helper function has a binary so i can have other programs call it if needed. That said, it's also used in the cap
#capRefresh()
#function gitup() {
#    for dir in */; do
#        cd "$dir"
#         git pull
#         cd ..
#    done
