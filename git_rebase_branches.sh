#!/usr/bin/env bash
# Rebase all branches in the current repository onto main

git checkout main
git pull
for branch in $(git branch --format="%(refname:short)" | grep -v "main"); do 
  git checkout "$branch" ;
  git rebase main ;
  git push
done
git checkout main