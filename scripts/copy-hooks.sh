cp scripts/pre-push .git/hooks/
chmod +x .git/hooks/pre-push

cp scripts/post-merge .git/hooks/
chmod +x .git/hooks/post-merge

cp scripts/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit

echo 'git hooks copied'