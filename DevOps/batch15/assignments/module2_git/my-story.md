HW link: https://docs.google.com/document/d/1RORsINBGEe8FrGCzgmIsQTtSn2NLQrb2c_Q0cdulXmU/edit?tab=t.0

# Chapter 1: The First Recipe

## Task A
```bash
mkdir nanur-khata
```
- Created empty directory

```bash
git config --global user.name "Pinku Deb Nath"
git config --global user.email "prantoran@gmail.com"
```
- Set global user and email

```bash
git init
# Initialized empty Git repository in /Users/prantoran/nanur-khata/.git/
```
- Initialize empty .git

## Task B
```bash
touch bhapa-pitha.md
git status
# On branch main

# No commits yet

# Untracked files:
#  (use "git add <file>..." to include in what will be committed)
#	bhapa-pitha.md

# nothing added to commit but untracked files present (use "git add" to track)
```

```bash
git add bhapa-pitha.md
git status
# On branch main

# No commits yet

# Changes to be committed:
#  (use "git rm --cached <file>..." to unstage)
#	new file:   bhapa-pitha.md
```

## Task C
```bash
cat > bhapa-pitha.md << EOF
# heredoc> One and a half cups of gur, not two!
# heredoc> EOF
cat bhapa-pitha.md
# One and a half cups of gur, not two!
```

```bash
git diff
diff --git a/bhapa-pitha.md b/bhapa-pitha.md
index e69de29..322171e 100644
--- a/bhapa-pitha.md
+++ b/bhapa-pitha.md
@@ -0,0 +1 @@
```

```bash
git diff --staged
diff --git a/bhapa-pitha.md b/bhapa-pitha.md
new file mode 100644
index 0000000..e69de29
```

The difference in output between `git diff` and `git diff --staged` is due to 
`--staged` the staging area with the last commit (HEAD) while the first one compares
the working directory to the staging area (changes not staged for next commit).

## Task D

```bash
git commit -m "docs: Update bhapa-pitha.md with gur instruction"
[main (root-commit) 8948ab8] docs: Update bhapa-pitha.md with gur instruction
 1 file changed, 1 insertion(+)
 create mode 100644 bhapa-pitha.md
```

## Task E
```bash
touch bazar-list.txt
git add bazar-list.txt
git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	new file:   bazar-list.txt

git reset bazar-list.txt
git status
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	bazar-list.txt

nothing added to commit but untracked files present (use "git add" to track)
```

# Chapter 2: The Secret Spice
## Task A
```bash
touch secret-masala.txt
touch a.tmp b.tmp
mkdir draft
git status
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	a.tmp
	b.tmp
	bazar-list.txt
	secret-masala.txt

nothing added to commit but untracked files present (use "git add" to track)
```

## Task B
```bash
cat > .gitignore << EOF
heredoc> secret-masala.txt
heredoc> *.tmp
heredoc> draft/
heredoc> EOF
git status
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	.gitignore
	bazar-list.txt

nothing added to commit but untracked files present (use "git add" to track)
```

# Chapter 3:  The Eid Special
## Task A
```bash
git branch
* main
prantoran@Mac nanur-khata % git branch eid-special
prantoran@Mac nanur-khata % git checkout eid-special
Switched to branch 'eid-special'
prantoran@Mac nanur-khata % git branch
* eid-special
  main
```

## Task B
```bash
touch biryani.md
git add biryani.md
git commit -m "docs: create biryani.md"
[eid-special debac62] docs: create biryani.md
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 biryani.md

touch shemai.md
git add shemai.md
git commit -m "docs: create shemai.md"
[eid-special 8b6d452] docs: create shemai.md
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 shemai.md
```

## Task C
```bash
ls
a.tmp			biryani.md
b.tmp			draft
bazar-list.txt		secret-masala.txt
bhapa-pitha.md		shemai.md
```
```bash
git checkout main
ls
a.tmp			bhapa-pitha.md
b.tmp			draft
bazar-list.txt		secret-masala.txt
```

The files `biryani.md` and `shemai.md` are not present in the main branch.

```bash
git log --oneline
8948ab8 (HEAD -> main) docs: Update bhapa-pitha.md with gur instruction

git merge eid-special
Updating 8948ab8..8b6d452
Fast-forward
 biryani.md | 0
 shemai.md  | 0
 2 files changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 biryani.md
 create mode 100644 shemai.md

git log --oneline
8b6d452 (HEAD -> main, eid-special) docs: create shemai.md
debac62 docs: create biryani.md
8948ab8 docs: Update bhapa-pitha.md with gur instruction
```

### Creating merge conflict

```bash
cat >> biryani.md << EOF
heredoc> From main
heredoc> EOF
git add biryani.md
git commit -m "docs: Update biryani.md from main"
[main 3aa1772] docs: Update biryani.md from main
 1 file changed, 1 insertion(+)
```

```bash
git branch
  eid-special
* main
git checkout eid-special
Switched to branch 'eid-special'
cat >> biryani.md << EOF
heredoc> From Eid-special
heredoc> EOF
git add biryani.md
git commit -m "docs: Update biryani.md from eid-special"
[eid-special a8605f9] docs: Update biryani.md from eid-special
 1 file changed, 1 insertion(+)
```

```bash
git branch
* eid-special
  main
git checkout main
Switched to branch 'main'
```
#### Conflict on merge
```bash
git merge eid-special
Auto-merging biryani.md
CONFLICT (content): Merge conflict in biryani.md
Automatic merge failed; fix conflicts and then commit the result.
```

```bash
git log --oneline
3aa1772 (HEAD -> main) docs: Update biryani.md from main
8b6d452 docs: create shemai.md
debac62 docs: create biryani.md
8948ab8 docs: Update bhapa-pitha.md with gur instruction
```

### Fix manually
```bash
cat biryani.md
<<<<<<< HEAD
From main
=======
From Eid-special
>>>>>>> eid-special
```

```bash
vim biryani.md
cat biryani.md
From main
From Eid-special
```

```bash
git commit
U	biryani.md
error: Committing is not possible because you have unmerged files.
hint: Fix them up in the work tree, and then use 'git add/rm <file>'
hint: as appropriate to mark resolution and make a commit.
fatal: Exiting because of an unresolved conflict.
```

```bash
git add biryani.md
```
```bash
git commit
<<<<<<< HEAD
From main
Merge branch 'eid-special'

# Conflicts:
#       biryani.md
#
# It looks like you may be committing a merge.
# If this is not correct, please run
#       git update-ref -d MERGE_HEAD
# and try again.


# Please enter the commit message for your changes. Lines starting
# with '#' will be ignored, and an empty message aborts the commit.
#
# On branch main
# All conflicts fixed but you are still merging.
#
# Changes to be committed:
#       modified:   biryani.md
#
# Untracked files:
#       .gitignore
"~/go/code/nanur-khata/.git/COMMIT_EDITMSG" 24L, 500B
Merge branch 'eid-special'

# Conflicts:
#       biryani.md
#
# It looks like you may be committing a merge.
# If this is not correct, please run
#       git update-ref -d MERGE_HEAD
# and try again.


# Please enter the commit message for your changes. Lines starting
# with '#' will be ignored, and an empty message aborts the commit.
#
# On branch main
# All conflicts fixed but you are still merging.
#
# Changes to be committed:
#       modified:   biryani.md
#
# Untracked files:
#       .gitignore

[main dbea99b] Merge branch 'eid-special'
```
#### Check logs
```bash
git log --oneline
dbea99b (HEAD -> main) Merge branch 'eid-special'
a8605f9 (eid-special) docs: Update biryani.md from eid-special
3aa1772 docs: Update biryani.md from main
8b6d452 docs: create shemai.md
debac62 docs: create biryani.md
8948ab8 docs: Update bhapa-pitha.md with gur instruction
```

# Chapter 4:  Mitu Joins In
## Task A
Create a GitHub repo, connect it with `git remote add origin [url]`, and `git push`.

```bash
gh repo create nanur-khata --public
✓ Created repository prantoran/nanur-khata on github.com
  https://github.com/prantoran/nanur-khata


A new release of gh is available: 2.94.0 → 2.102.0
To upgrade, run: brew upgrade gh
https://github.com/cli/cli/releases/tag/v2.102.0
```
