
# alias gwip="[[ '$(git rev-parse --abbrev-ref HEAD)' != 'main' ]] && git add -A && git commit -m 'wip' && git push -u origin HEAD"
alias gs="git status -sb"
alias gundo="git reset --soft HEAD~1"
alias gucommit="git add -A && git commit --amend --no-edit"
alias gl="git log --oneline --graph --decorate -20"

# commit-push
# function compush () {
#     git add -A && git commit -m "$1" && git push -u origin HEAD
# }

# git reset to main
# function grmain () {
#     git fetch --quiet
#     git checkout main

#     if [ -n "$(git rev-list @{u}..HEAD 2>/dev/null)" ]; then
#         echo "There are unpushed commits, exiting"
#         return 1
#     fi

#     git reset --hard origin/main
# }

