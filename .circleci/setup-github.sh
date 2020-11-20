#!/bin/bash

git config user.name "$USER_NAME"
git config user.email "$USER_EMAIL"

ls -al

git stash
git checkout gh-pages
git pull origin gh-pages

ls -al

find . -maxdepth 1 ! -name '_site' ! -name '.git' ! -name '.gitignore' ! -name '.circleci' -exec rm -rf {} \;
mv _site/* .
rm -R _site/

ls -al

git add -fA
git commit --allow-empty -m "$(git log master -1 --pretty=%B)"
git push -f origin gh-pages

echo "deployed successfully"